module Database.Redis.Streams.ConsumerGroup.Streamly where

import Control.Monad.Catch
import Control.Monad.IO.Class
import Database.Redis
import Database.Redis.Internal.Instances ()
import Database.Redis.Streams.ConsumerGroup
import Database.Redis.Streams.SpecialMessageID (autoclaimNewScanMessageID)
import Database.Redis.Streams.Types.ConsumerGroup
import Database.Redis.Streams.Types.Extras
import Database.Redis.Streams.Types.Stream
import Streamly.Data.Unfold (Unfold)
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

type EndCondition = IO Bool

fromStreamAsConsumer ::
    IsStream t => Consumer -> XReadOpts -> Maybe EndCondition -> t Redis StreamsRecord
fromStreamAsConsumer consumer opts endCondition = Streamly.unfold (fromStreamAsConsumerUnfold consumer opts endCondition) ()

fromStreamAsConsumerUnfold :: Consumer -> XReadOpts -> Maybe EndCondition -> Unfold Redis () StreamsRecord
fromStreamAsConsumerUnfold consumer opts endCondition =
    Unfold.many
        (Unfold.unfoldrM (const readStreamAsConsumerMaybeEnd))
        Unfold.fromList
  where
    readStreamAsConsumerMaybeEnd = case endCondition of
        Nothing -> readStreamAsConsumerProducer
        Just checkStopStream -> do
            stopStream <- liftIO checkStopStream
            if stopStream then pure Nothing else readStreamAsConsumerProducer
    readStreamAsConsumerProducer =
        readStreamAsConsumer consumer opts >>= \case
            Left err -> throwM err -- Possible only when redis sends error message back
            Right records -> pure $ Just (records, ())

fromPendingMessages ::
    IsStream t => Consumer -> XAutoclaimOpts -> t Redis StreamsRecord
fromPendingMessages consumer = fromPendingMessagesStartingFrom consumer autoclaimNewScanMessageID

fromPendingMessagesStartingFrom ::
    IsStream t => Consumer -> MessageID -> XAutoclaimOpts -> t Redis StreamsRecord
fromPendingMessagesStartingFrom consumer lstMsgId opts =
    Streamly.unfold (fromPendingMessagesUnfold consumer opts) (Just lstMsgId)

fromPendingMessagesUnfold :: Consumer -> XAutoclaimOpts -> Unfold Redis (Maybe MessageID) StreamsRecord
fromPendingMessagesUnfold consumer autoclaimOpts =
    Unfold.many
        (Unfold.unfoldrM readPendingMessagesProdcer)
        Unfold.fromList
  where
    readPendingMessagesProdcer Nothing = pure Nothing
    readPendingMessagesProdcer (Just lstMsgId) =
        readPendingMessages consumer lstMsgId autoclaimOpts >>= \case
            Left err -> throwM err -- Possible only when redis sends error message back
            Right (newMsgId, records) -> pure $ Just (records, newMsgId)
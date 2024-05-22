module Database.Redis.Internal.Streams.ConsumerGroup.Streamly where

import Data.Function
import Database.Redis
import Database.Redis.Internal.Instances ()
import Database.Redis.Streams.ConsumerGroup
import Database.Redis.Streams.SpecialMessageID (autoclaimNewScanMessageID)
import Database.Redis.Streams.Types
import GHC.Generics
import Streamly.Data.Stream.Prelude as Stream
import Streamly.Data.Unfold (Unfold)
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Internal.Data.Stream as StreamEx

data ClaimReadOptions = ClaimReadOptions
    { xAutoclaimOpts :: XAutoclaimOpts
    , delay :: Double
    }
    deriving (Show, Eq, Generic)

fromStreamAsConsumer :: Consumer -> XReadOpts -> Stream Redis StreamsRecord
fromStreamAsConsumer consumer opts = Stream.unfold (fromStreamAsConsumerUnfold consumer opts) mempty

fromStreamAsConsumerUnfold :: Consumer -> XReadOpts -> Unfold Redis () StreamsRecord
fromStreamAsConsumerUnfold consumer opts =
    Unfold.many
        Unfold.fromList
        (Unfold.unfoldrM (const readStreamAsConsumerProducer))
  where
    readStreamAsConsumerProducer =
        readStreamAsConsumer consumer opts >>= \case
            Left _err -> readStreamAsConsumerProducer -- Possible only when redis sends error message back
            Right records -> pure $ Just (records, ())

-- | Infinity stream of PEL messages with some delay in secs
fromPendingMessagesWithDelay :: Consumer -> XAutoclaimOpts -> Double -> Stream Redis StreamsRecord
fromPendingMessagesWithDelay consumer opts delay' =
    Stream.repeat (fromPendingMessages consumer opts)
        & StreamEx.delayPost delay'
        & Stream.concatMap id

fromPendingMessages ::
    Consumer -> XAutoclaimOpts -> Stream Redis StreamsRecord
fromPendingMessages consumer = fromPendingMessagesStartingFrom consumer autoclaimNewScanMessageID

fromPendingMessagesStartingFrom ::
    Consumer -> MessageID -> XAutoclaimOpts -> Stream Redis StreamsRecord
fromPendingMessagesStartingFrom consumer lstMsgId opts =
    Stream.unfold (fromPendingMessagesUnfold consumer opts) (Just lstMsgId)

fromPendingMessagesUnfold :: Consumer -> XAutoclaimOpts -> Unfold Redis (Maybe MessageID) StreamsRecord
fromPendingMessagesUnfold consumer autoclaimOpts =
    Unfold.many
        Unfold.fromList
        (Unfold.unfoldrM readPendingMessagesProdcer)
  where
    readPendingMessagesProdcer Nothing = pure Nothing
    readPendingMessagesProdcer lstMsg@(Just lstMsgId) =
        readPendingMessages consumer lstMsgId autoclaimOpts >>= \case
            Left _err -> readPendingMessagesProdcer lstMsg -- Possible only when redis sends error message back
            Right (newMsgId, records) -> pure $ Just (records, newMsgId)
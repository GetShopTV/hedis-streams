module Database.Redis.Internal.Streams.ConsumerGroup.Streamly where

import Data.Function
import Database.Redis
import Database.Redis.Internal.Instances ()
import Database.Redis.Streams.ConsumerGroup
import Database.Redis.Streams.SpecialMessageID (autoclaimNewScanMessageID)
import Database.Redis.Streams.Types
import GHC.Generics
import Streamly.Data.Unfold (Unfold)
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Internal.Data.Stream.IsStream qualified as StreamEx
import Streamly.Prelude (IsStream, SerialT)
import Streamly.Prelude qualified as Streamly

data ClaimReadOptions = ClaimReadOptions
    { xAutoclaimOpts :: XAutoclaimOpts
    , delay :: Double
    }
    deriving (Show, Eq, Generic)

fromStreamAsConsumer ::
    IsStream t => Consumer -> XReadOpts -> t Redis StreamsRecord
fromStreamAsConsumer consumer opts = Streamly.unfold (fromStreamAsConsumerUnfold consumer opts) ()

fromStreamAsConsumerUnfold :: Consumer -> XReadOpts -> Unfold Redis () StreamsRecord
fromStreamAsConsumerUnfold consumer opts =
    Unfold.many
        (Unfold.unfoldrM (const readStreamAsConsumerProducer))
        Unfold.fromList
  where
    readStreamAsConsumerProducer =
        readStreamAsConsumer consumer opts >>= \case
            Left _err -> readStreamAsConsumerProducer -- Possible only when redis sends error message back
            Right records -> pure $ Just (records, ())

-- | Infinity stream of PEL messages with some delay in secs
fromPendingMessagesWithDelay :: IsStream t => Consumer -> XAutoclaimOpts -> Double -> t Redis StreamsRecord
fromPendingMessagesWithDelay consumer opts delay =
    Streamly.repeat @SerialT (fromPendingMessages consumer opts)
        & StreamEx.delayPost delay
        & Streamly.concatMap id
        & Streamly.fromSerial

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
    readPendingMessagesProdcer lstMsg@(Just lstMsgId) =
        readPendingMessages consumer lstMsgId autoclaimOpts >>= \case
            Left _err -> readPendingMessagesProdcer lstMsg -- Possible only when redis sends error message back
            Right (newMsgId, records) -> pure $ Just (records, newMsgId)
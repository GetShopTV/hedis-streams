module Database.Redis.Streams.ConsumerGroup.Streamly.Serialize where

import Data.Function
import Data.Store
import Database.Redis
import Database.Redis.Streams.Common
import Database.Redis.Streams.ConsumerGroup.Streamly qualified as SRedisConsumerGroup
import Database.Redis.Streams.SpecialMessageID
import Database.Redis.Streams.Types
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

fromStreamAsConsumer ::
    (IsStream t, Store a) =>
    Consumer ->
    XReadOpts ->
    t Redis (MessageID, Either PeekException a)
fromStreamAsConsumer consumer opts =
    SRedisConsumerGroup.fromStreamAsConsumer consumer opts
        & Streamly.unfoldMany deserializedStreamsRecordUnfold

fromPendingMessages ::
    (IsStream t, Store a) =>
    Consumer ->
    XAutoclaimOpts ->
    t Redis (MessageID, Either PeekException a)
fromPendingMessages consumer = fromPendingMessagesStartingFrom consumer autoclaimNewScanMessageID

fromPendingMessagesStartingFrom ::
    (IsStream t, Store a) =>
    Consumer ->
    MessageID ->
    XAutoclaimOpts ->
    t Redis (MessageID, Either PeekException a)
fromPendingMessagesStartingFrom consumer lstMsgId opts =
    SRedisConsumerGroup.fromPendingMessagesStartingFrom consumer lstMsgId opts
        & Streamly.unfoldMany deserializedStreamsRecordUnfold
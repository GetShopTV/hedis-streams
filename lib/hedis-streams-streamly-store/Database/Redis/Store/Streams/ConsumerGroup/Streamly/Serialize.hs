module Database.Redis.Store.Streams.ConsumerGroup.Streamly.Serialize where

import Data.Function
import Data.Store
import Database.Redis
import Database.Redis.Store.Streams.Common
import Database.Redis.Streams.ConsumerGroup.Streamly (EndCondition)
import Database.Redis.Streams.ConsumerGroup.Streamly qualified as SRedisConsumerGroup
import Database.Redis.Streams.SpecialMessageID (autoclaimNewScanMessageID)
import Database.Redis.Streams.Types
import Database.Redis.Streams.Types.Extras
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

fromStreamAsConsumer ::
    (IsStream t, Store a) =>
    Consumer ->
    XReadOpts ->
    Maybe EndCondition ->
    t Redis (MessageID, Either PeekException a)
fromStreamAsConsumer consumer opts endCondition =
    SRedisConsumerGroup.fromStreamAsConsumer consumer opts endCondition
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
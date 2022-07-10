module Database.Redis.Store.Streams.Streamly.Serialize where

import Data.Function
import Data.Store
import Database.Redis (Redis, StreamsRecord (..))
import Database.Redis qualified as Redis
import Database.Redis.Store.Streams.Common
import Database.Redis.Streams.SpecialMessageID
import Database.Redis.Streams.Streamly qualified as SRedis
import Database.Redis.Streams.Types
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

fromStream ::
    (IsStream t, Store a) =>
    StreamKey ->
    Redis.XReadOpts ->
    Maybe SRedis.EndCondition ->
    t Redis (MessageID, Either PeekException a)
fromStream key opts endCondition = fromStreamStartingFrom key opts endCondition newestMessageID

fromStreamStartingFrom ::
    (IsStream t, Store a) =>
    StreamKey ->
    Redis.XReadOpts ->
    Maybe SRedis.EndCondition ->
    MessageID ->
    t Redis (MessageID, Either PeekException a)
fromStreamStartingFrom key opts endCondition startMsgId =
    SRedis.fromStreamStartingFrom key opts endCondition startMsgId
        & Streamly.unfoldMany deserializedStreamsRecordUnfold

sendStream ::
    (IsStream t, Store a) =>
    StreamKey ->
    t Redis a ->
    t Redis MessageID
sendStream key inputStream =
    inputStream
        & Streamly.map toStoreEntry
        & SRedis.sendStream key
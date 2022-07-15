module Database.Redis.Streams.Streamly.Serialize where

import Data.Function
import Data.Store
import Database.Redis (Redis, StreamsRecord (..))
import Database.Redis qualified as Redis
import Database.Redis.Streams.Common
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
    t Redis (MessageID, EntryField, Either PeekException a)
fromStream key opts = fromStreamStartingFrom key opts newestMessageID

fromStreamStartingFrom ::
    (IsStream t, Store a) =>
    StreamKey ->
    Redis.XReadOpts ->
    MessageID ->
    t Redis (MessageID, EntryField, Either PeekException a)
fromStreamStartingFrom key opts startMsgId =
    SRedis.fromStreamStartingFrom key opts startMsgId
        & Streamly.unfoldMany deserializedStreamsRecordUnfold

sendStream ::
    (IsStream t, Store a) =>
    StreamKey ->
    EntryField ->
    t Redis a ->
    t Redis MessageID
sendStream key field inputStream =
    inputStream
        & Streamly.map (toStoreEntryWithField field)
        & SRedis.sendStream key
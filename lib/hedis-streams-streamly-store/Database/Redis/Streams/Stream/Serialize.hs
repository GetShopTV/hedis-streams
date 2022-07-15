module Database.Redis.Streams.Stream.Serialize where

import Data.ByteString
import Data.Store
import Database.Redis
import Database.Redis.Streams.Common
import Database.Redis.Streams.Stream qualified as SRedis
import Database.Redis.Streams.Types
import GHC.Generics

-- | Serialize with store and send some data using Redis stream.
sendUpstream ::
    (Store a) =>
    StreamKey ->
    EntryField ->
    a ->
    Redis (Either RedisStreamSomeError ByteString)
sendUpstream key field = SRedis.sendUpstream key . toStoreEntry
  where
    toStoreEntry = toStoreEntryWithField field

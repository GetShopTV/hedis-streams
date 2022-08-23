{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

module Database.Redis.Streams.Store.Common where

import Data.ByteString
import Data.Function
import Data.Store
import Database.Redis hiding (decode)
import Database.Redis.Streams.Store.Internal
import Database.Redis.Streams.Stream
import Database.Redis.Streams.Streamly (RedisStreamRead (..))
import Database.Redis.Streams.Streamly qualified as SRedis
import Database.Redis.Streams.Types
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

{- | Placeholder entry field to store serialized data.
 If possible use your type version as key.
-}
storePlaceholderStreamEntryField :: EntryField
storePlaceholderStreamEntryField = EntryField "noversion"

-- | Serialize with store and send some data using Redis stream.
sendUpstream ::
    (Store a) =>
    StreamKey ->
    EntryField ->
    a ->
    Redis (Either RedisStreamSomeError ByteString)
sendUpstream key field =
    Database.Redis.Streams.Stream.sendUpstream key . toStoreEntry
  where
    toStoreEntry = toStoreEntryWithField field

streamSink ::
    (IsStream t, Store a) =>
    StreamKey ->
    EntryField ->
    t Redis a ->
    t Redis MessageID
streamSink key field inputStream =
    inputStream
        & Streamly.map (toStoreEntryWithField field)
        & SRedis.streamSink key

fromStream ::
    forall mode a t.
    (RedisStreamRead mode, IsStream t, Store a) =>
    ReadUsing mode ->
    ReadOptions mode ->
    t Redis (MessageID, EntryField, Either PeekException a)
fromStream using opts =
    SRedis.fromStream @mode using opts
        & Streamly.unfoldMany deserializedStreamsRecordUnfold
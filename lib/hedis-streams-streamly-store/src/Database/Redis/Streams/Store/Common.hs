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
import Streamly.Data.Stream.Prelude as Stream
import Streamly.Data.Unfold qualified as Unfold

{- | Placeholder entry field to store serialized data.
 If possible use your type version as key.
-}
storePlaceholderStreamEntryField :: EntryField
storePlaceholderStreamEntryField = EntryField "noversion"

-- | Serialize with store and send some data using Redis stream.
sendUpstream ::
    (Store a) =>
    StreamKey ->
    TrimOpts ->
    EntryField ->
    a ->
    Redis (Either RedisStreamSomeError ByteString)
sendUpstream key trimOpts field =
    Database.Redis.Streams.Stream.sendUpstream key trimOpts . toStoreEntry
  where
    toStoreEntry = toStoreEntryWithField field

streamSink ::
    (Store a) =>
    StreamKey ->
    TrimOpts ->
    EntryField ->
    Stream Redis a ->
    Stream Redis MessageID
streamSink key trimOpts field inputStream =
    inputStream
        & fmap (toStoreEntryWithField field)
        & SRedis.streamSink key trimOpts

fromStream ::
    forall mode a.
    (RedisStreamRead mode, Store a) =>
    ReadUsing mode ->
    ReadOptions mode ->
    Stream Redis (MessageID, EntryField, Either PeekException a)
fromStream using opts =
    SRedis.fromStream @mode using opts
        & Stream.unfoldMany deserializedStreamsRecordUnfold
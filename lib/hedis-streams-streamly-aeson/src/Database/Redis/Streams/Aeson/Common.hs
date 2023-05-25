module Database.Redis.Streams.Aeson.Common where

import Control.Exception
import Data.Aeson
import Data.Aeson qualified as Aeson
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as BS
import Data.Function
import Data.Text.Encoding qualified as TE
import Database.Redis
import Database.Redis.Streams.Stream qualified
import Database.Redis.Streams.Streamly qualified as SRedis
import Database.Redis.Streams.Types.Error
import Database.Redis.Streams.Types.Stream
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

newtype NonObjectJSONException = NonObjectJSONException String
    deriving (Show, Eq)
    deriving anyclass (Exception)

valueToEntry :: Value -> Entry
valueToEntry (Object km) =
    Entry $ convert <$> KeyMap.toList km
  where
    convert (field, value) = (entryF, entryV)
      where
        entryF = EntryField . TE.encodeUtf8 . AesonKey.toText $ field
        entryV = EntryValue $ case value of
            Aeson.String s -> TE.encodeUtf8 s
            val -> BS.toStrict . encode $ val
-- TODO: type check guarantee of record \ json object
valueToEntry val = throw $ NonObjectJSONException $ show val
{-# INLINE valueToEntry #-}

streamSink ::
    (ToJSON a) =>
    IsStream t =>
    StreamKey ->
    TrimOpts ->
    t Redis a ->
    t Redis MessageID
streamSink streamOut trimOpts source =
    source
        & Streamly.map (valueToEntry . toJSON)
        & SRedis.streamSink streamOut trimOpts

sendUpstream ::
    ToJSON a =>
    StreamKey ->
    TrimOpts ->
    a ->
    Redis (Either RedisStreamSomeError BS.ByteString)
sendUpstream key trimOpts =
    Database.Redis.Streams.Stream.sendUpstream key trimOpts . valueToEntry . toJSON

module Database.Redis.Streams.Aeson.Common where

import Control.Exception
import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as BS
import Data.Function
import Database.Redis
import Database.Redis.Streams.Streamly qualified as SRedis
import Database.Redis.Streams.Types.Stream
import Streamly.Prelude (IsStream)
import Streamly.Prelude qualified as Streamly

data NonObjectJSONException = NonObjectJSONException String
    deriving (Show, Eq)
    deriving anyclass (Exception)

streamSink ::
    (ToJSON a) =>
    IsStream t =>
    StreamKey ->
    t Redis a ->
    t Redis MessageID
streamSink streamOut source =
    source
        & Streamly.map (valueToEntry . toJSON)
        & SRedis.streamSink streamOut
  where
    valueToEntry (Object km) =
        Entry [(EntryField . BS.toStrict . encode $ field, EntryValue . BS.toStrict . encode $ value) | (field, value) <- KeyMap.toList km]
    -- TODO: type check guarantee of record \ json object
    valueToEntry val = throw $ NonObjectJSONException $ show val
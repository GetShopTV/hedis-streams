module Database.Redis.Streams where

import           Data.ByteString                ( ByteString )
import qualified Data.ByteString.Char8         as Ch8
import qualified Database.Redis                as Redis

sendUpstream
    :: (Redis.RedisCtx m (Either a), Show a)
    => String
    -> ByteString
    -> ByteString
    -> m ByteString
sendUpstream streamOut key value = do
    result <- Redis.xadd (Ch8.pack streamOut) "*" [(key, value)]
    case result of
        Right msgId -> return msgId
        err         -> error $ "Unexpected redis error: " <> show err


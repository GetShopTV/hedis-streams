module Database.Redis.Streams where

import           Data.ByteString                ( ByteString )
import qualified Data.ByteString.Char8         as Ch8
import qualified Database.Redis                as Redis
import           Database.Redis.Internal.Instances
                                                ( )

sendUpstream
    :: (Redis.RedisCtx m (Either a), Show a)
    => String
    -> ByteString
    -> ByteString
    -> m (Either a ByteString)
sendUpstream streamOut key value =
    Redis.xadd (Ch8.pack streamOut) "*" [(key, value)]


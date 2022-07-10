module Database.Redis.Streams.Types.Extras where

import Data.ByteString
import Database.Redis
import Database.Redis qualified as Redis

data XAutoclaimResponse = XAutoclaimResponse
    { nextStreamId :: ByteString
    , records :: [StreamsRecord]
    }
    deriving (Show, Eq)

instance RedisResult XAutoclaimResponse where
    decode (MultiBulk (Just (Bulk (Just nextStreamId) : MultiBulk (Just rawRecords) : _))) = do
        records <- mapM decode rawRecords
        return XAutoclaimResponse{nextStreamId, records}
    decode a = Left a

data XAutoclaimOpts = XAutoclaimOpts
    { -- | In milliseconds
      minIdleTime :: Integer
    , count :: Maybe Integer
    }
    deriving (Show, Eq)
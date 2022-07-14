module Database.Redis.Streams.ConsumerGroup.Serialize where

import Codec.Winery qualified as Winery
import Data.ByteString.Builder qualified as BSB
import Data.ByteString.Lazy qualified as BSL
import Database.Redis
import Database.Redis.Streams.Common
import Database.Redis.Streams.ConsumerGroup qualified as RedisCG
import Database.Redis.Streams.Types

-- | Create default .
getOrCreateConsumerGroup :: Winery.Serialise a => proxy a -> Redis (Either RedisStreamSomeError ConsumerGroup)
getOrCreateConsumerGroup proxy = RedisCG.getOrCreateConsumerGroup (streamKeyFromData proxy) storeStreamConsumerGroupName
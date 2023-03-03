module Database.Redis.Streams.SpecialMessageID where

import Database.Redis.Streams.Types

-- | Special "*" message id to auto-generate a unique ID.
autogenMessageID :: MessageID
autogenMessageID = MessageID "*"

{- | Special "$" message id to signal the stream that we want only the new things.

 It is very important to understand that it should be used only for the first call 'readStream'.
-}
newestMessageID :: MessageID
newestMessageID = MessageID "$"

-- | Special ">" message id for next non-delivered message in consumer group.
nextNotDeliveredMessageID :: MessageID
nextNotDeliveredMessageID = MessageID ">"

{- | Special "0-0" message id that:
 - When returned from XAUTOCLAIM marks that all suitable PEL entries had scanned;
 - Will scan all suitable PEL entries when used as starting message id in XAUTOCLAIM.
-}
autoclaimNewScanMessageID :: MessageID
autoclaimNewScanMessageID = MessageID "0-0"

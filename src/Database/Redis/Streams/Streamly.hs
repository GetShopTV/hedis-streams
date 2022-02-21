{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}

module Database.Redis.Streams.Streamly where

import           Data.ByteString                ( ByteString )
import qualified Data.ByteString.Char8         as Ch8

import           Database.Redis
import qualified Database.Redis                as Redis

import qualified Streamly.Data.Fold            as Fold
import           Streamly.Data.Fold             ( Fold )
import qualified Streamly.Data.Unfold          as Unfold
import           Streamly.Data.Unfold           ( Unfold )
import qualified Streamly.Prelude              as Stream
import           Streamly.Prelude               ( IsStream )


read :: IsStream t => String -> t Redis (ByteString, ByteString)
read streamId = readStartingFrom streamId "$"

readStartingFrom
    :: IsStream t => String -> ByteString -> t Redis (ByteString, ByteString)
readStartingFrom streamId = Stream.unfold $ readStartingFromUnfold streamId

readStartingFromUnfold
    :: String -> Unfold Redis ByteString (ByteString, ByteString)
readStartingFromUnfold streamIn = Unfold.many
    (Unfold.unfoldrM $ getResponseStep streamIn)
    Unfold.fromList
  where
    getResponseStep streamIn oldRecordId = do
        let xReadOpts = Redis.defaultXreadOpts { Redis.block = Just 0 }
        result <- Redis.xreadOpts [(Ch8.pack streamIn, oldRecordId)] xReadOpts
        case result of
            Right (Just xResponses) -> do
                    -- Should be one responce for one stream
                let records =
                        concat
                            [ Redis.records xResponse
                            | xResponse <- xResponses
                            ]  -- , stream xResponse == Ch8.pack streamIn
                    lastRecordId = recordId . Prelude.last $ records
                    pairs        = Prelude.concatMap Redis.keyValues records
                pure $ Just (pairs, lastRecordId)
            Right Nothing -> pure $ Just ([], oldRecordId)
            err           -> error $ "Unexpected redis error: " <> show err

send :: String -> Stream.SerialT Redis (ByteString, ByteString) -> Redis ()
send streamOut = Stream.fold (sendFold streamOut)

sendFold :: String -> Fold Redis (ByteString, ByteString) ()
sendFold streamOut = Fold.foldlM' (const step) (pure ())
  where
    step (key, value) = do
        result <- Redis.xadd (Ch8.pack streamOut) "*" [(key, value)]
        case result of
            Right _ -> return ()
            err     -> error $ "Unexpected redis error: " <> show err


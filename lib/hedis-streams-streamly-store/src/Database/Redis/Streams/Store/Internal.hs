module Database.Redis.Streams.Store.Internal where

import Data.Store
import Database.Redis hiding (decode)
import Database.Redis.Streams.Types
import Streamly.Data.Unfold qualified as Unfold

toStoreEntryWithField :: (Store a) => EntryField -> a -> Entry
toStoreEntryWithField field x = Entry [(field, EntryValue $ encode x)]

deserializedStreamsRecordUnfold ::
    (Store a) => Unfold.Unfold Redis StreamsRecord (MessageID, EntryField, Either PeekException a)
deserializedStreamsRecordUnfold =
    Unfold.many
        -- Flatten
        Unfold.fromList
        -- Extract stream entries
        -- There always should be one key/value pair in store stream entry
        -- Pair entry with it's message id, decode the value
        ( Unfold.function
            ( \StreamsRecord{recordId, keyValues} ->
                -- Key should be "version" of your datatype.
                -- Allows multiple serialized types in the same message
                fmap (\(versionKey, value) -> (MessageID recordId, EntryField versionKey, decode value)) keyValues
            )
        )
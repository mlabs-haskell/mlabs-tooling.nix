import Control.Monad (when)
import MyDep (mydep)

main :: IO ()
main =
  Control.Monad.when (mydep == ()) $ putStrLn "Hello, World!"

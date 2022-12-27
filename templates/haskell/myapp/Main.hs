import MyDep (mydep)
import Control.Monad (when)

main :: IO ()
main =
  Control.Monad.when (mydep == ()) $ putStrLn "Hello, World!"

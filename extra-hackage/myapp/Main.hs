import MyDep (mydep)

main :: IO ()
main =
    if mydep == () then putStrLn "Hello, World!" else return ()

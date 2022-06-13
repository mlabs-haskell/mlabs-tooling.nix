Add dependencies to haskell.nix project via `extra-hackages` and `extra-hackage-tarballs`.


```nix
let
  myHackage = mkHackagesFor system compiler-nix-name [ ./mydep ./mydepdep ];
in
cabalProject {
  inherit (myHackages) extra-hackages extra-hackage-tarballs modules;
  # ...
};
```

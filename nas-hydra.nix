{ config, pkgs, lib, ... }:

let
  hydraRev = "a4469f8b0fedbac6764778c4c3426656b44c29a1";
  hydraSrc = pkgs.fetchFromGitHub {
    owner = "cleverca22";
    repo = "hydra";
    sha256 = "0zx19macxah6b69nzgqc34fm9vl8md4sbp07p0pnqniallnmf6gg";
    rev = hydraRev;
  };
  hydraSrc' = {
    outPath = hydraSrc;
    rev = hydraRev;
    revCount = 1234;
  };
  hydra-fork = (import (hydraSrc + "/release.nix") { nixpkgs = pkgs.path; hydraSrc = hydraSrc'; }).build.x86_64-linux;
  patched-hydra = pkgs.hydra.overrideDerivation (drv: {
    patches = [
      ./extra-debug.patch
    ];
  });
  passwords = import ./load-secrets.nix;
in {
  systemd.services.hydra-queue-runner = {
    serviceConfig = {
      ExecStart = lib.mkForce "@${config.services.hydra.package}/bin/hydra-queue-runner hydra-queue-runner -vvvvvv";
    };
  };
  systemd.services.hydra-evaluator.path = [ pkgs.jq pkgs.gawk ];
  services = {
    hydra = {
      useSubstitutes = true;
      package = hydra-fork;
      enable = true;
      hydraURL = "https://hydra.angeldsis.com";
      notificationSender = "cleverca22@gmail.com";
      minimumDiskFree = 2;
      minimumDiskFreeEvaluator = 1;
      listenHost = "localhost";
      port = 3001;
      extraConfig = with passwords; ''
        max_output_size = ${toString (1024*1024*1024*3)} # 3gig
        max_concurrent_evals = 1
        <github_authorization>
          input-output-hk = ${token1}
          cleverca22 = ${token1}
          arcane-chat = ${token1}
          haskell-capnp = ${token1}
          zenhack = ${token1}
          language-ninja = ${token1}
          awakesecurity = ${token1}
          zenhack = ${token2}
          taktoa = ${token3}
        </github_authorization>
        <githubstatus>
          jobs = toxvpn:toxvpn.*
          inputs = toxvpn
          excludeBuildFromContext = 1
        </githubstatus>
        <githubstatus>
          jobs = not-os:notos.*
          inputs = notos
          excludeBuildFromContext = 1
        </githubstatus>
        <githubstatus>
          jobs = haskell-capnp:zenhack.*
          inputs = src
          excludeBuildFromContext = 1
        </githubstatus>
      '';
    };
    nginx = {
      virtualHosts = {
        "hydra.angeldsis.com" = {
          enableACME = true;
          forceSSL = true;
          locations."/".extraConfig = ''
            proxy_pass http://localhost:3001;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header  X-Real-IP         $remote_addr;
            proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
          '';
        };
      };
    };
  };
}

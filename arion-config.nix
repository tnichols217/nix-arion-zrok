{ flake ? (builtins.getFlake (toString ./.)).packages.x86_64-linux, isCompose ? false, ... }:
{ lib, ... }:
let
  # Docker info
  ZITI_IMAGE="openziti/quickstart";
  ZITI_IMAGE_TAG=""; #TODO
  ZITI_IMAGE_DIGEST="";
  ZITI_SHA256="";

  ZAC_IMAGE="openziti/zac";
  ZAC_IMAGE_TAG=""; #TODO
  ZAC_IMAGE_DIGEST="";
  ZAC_SHA256="";

  environment = rec {
    # User details
    ZITI_USER="admin";

    # controller address/port information
    ZITI_CTRL_NAME="ziti-controller";
    ZITI_CTRL_EDGE_ADVERTISED_ADDRESS="ziti-edge-controller";
    ZITI_CTRL_ADVERTISED_ADDRESS="ziti-controller";

    ZITI_CTRL_EDGE_IP_OVERRIDE="127.0.0.1";
    ZITI_CTRL_EDGE_ADVERTISED_PORT=1280;
    ZITI_CTRL_ADVERTISED_PORT=6262;

    # The duration of the enrollment period (in minutes), default if not set. shown - 7days
    ZITI_EDGE_IDENTITY_ENROLLMENT_DURATION=10080;
    ZITI_ROUTER_ENROLLMENT_DURATION=10080;

    # router address/port information
    ZITI_ROUTER_NAME="ziti-edge-router";
    ZITI_ROUTER_ADVERTISED_ADDRESS="ziti-edge-router";
    ZITI_ROUTER_PORT=3022;
    ZITI_ROUTER_LISTENER_BIND_PORT=10080;
    ZITI_ROUTER_ROLES="public";

    ZAC_SERVER_CERT_CHAIN="/persistent/pki/${ZITI_CTRL_EDGE_ADVERTISED_ADDRESS}-intermediate/certs/${ZITI_CTRL_EDGE_ADVERTISED_ADDRESS}-server.cert";
    ZAC_SERVER_KEY="/persistent/pki/${ZITI_CTRL_EDGE_ADVERTISED_ADDRESS}-intermediate/keys/${ZITI_CTRL_EDGE_ADVERTISED_ADDRESS}-server.key";
    PORTTLS=8443;
  };

  depends_on = {
    ziti-controller = {
      condition = "service_healthy";
    };
  };

  networks = [ "ziti" ];
  volumes = [ "ziti-fs:/persistent" ];

  image = "${ZITI_IMAGE}";
  imageFile = pkgs.dockerTools.pullImage{
    imageName = "${ZITI_IMAGE}";
    finalImageTag = "${ZITI_IMAGE_TAG}";
    imageDigest = "${ZITI_IMAGE_DIGEST}";
    sha256 = "${ZITI_SHA256}";
  };
in
{
  project.name = "zrok";
  inherit networks;
  volumes = [ "ziti-fs" ];
  services = {
    ziti-controller = {
      service = {
        inherit imageFile image environment volumes;
        healthcheck = {
          test = [ "curl" "-m" "1" "-s" "-k" "-f" "https://${environment.ZITI_CTRL_EDGE_ADVERTISED_ADDRESS}:${environment.ZITI_CTRL_EDGE_ADVERTISED_PORT}/edge/client/v1/version" ];
          interval = "1s";
          timeout = "3s";
          retries = "30";
        };
        # TODO volumes
        ports = [
          "${environment.ZITI_CTRL_EDGE_ADVERTISED_PORT}:${environment.ZITI_CTRL_EDGE_ADVERTISED_PORT}"
          "${environment.ZITI_CTRL_ADVERTISED_PORT}:${environment.ZITI_CTRL_ADVERTISED_PORT}"
        ];
        networks = {
          ziti = {
            aliases = [ "${environment.ZITI_CTRL_EDGE_ADVERTISED_ADDRESS}" ];
          };
        };
        entrypoint = "/var/openziti/scripts/run-controller.sh";
      };
      build.image = lib.mkForce (imageFile);
    };
    ziti-controller-init-container = {
      service = {
        # TODO volumes
        inherit environment depends_on networks volumes;
        entrypoint = "/var/openziti/scripts/run-with-ziti-cli.sh";
        command = ["/var/openziti/scripts/access-control.sh"];
      };
      build.image = lib.mkForce (imageFile);
    };
    ziti-edge-router = {
      service = {
        # TODO volumes
        inherit environment depends_on networks volumes;
        ports = [
          "${environment.ZITI_ROUTER_PORT}:${environment.ZITI_ROUTER_PORT}"
          "${environment.ZITI_ROUTER_LISTENER_BIND_PORT}:${environment.ZITI_ROUTER_LISTENER_BIND_PORT}"
        ];
        entrypoint = "/bin/bash";
        command = ["/var/openziti/scripts/run-router.sh" "edge"];
      };
      build.image = lib.mkForce (imageFile);
    };
    ziti-console = {
      service = {
        # TODO volumes
        inherit environment depends_on networks volumes;
        ports = [
          "${environment.ZITI_ROUTER_PORT}:${environment.ZITI_ROUTER_PORT}"
          "${environment.ZITI_ROUTER_LISTENER_BIND_PORT}:${environment.ZITI_ROUTER_LISTENER_BIND_PORT}"
        ];
        working_dir = "/usr/src/app";
      };
      build.image = lib.mkForce (pkgs.dockerTools.pullImage{
        imageName = "${ZAC_IMAGE}";
        finalImageTag = "${ZAC_IMAGE_TAG}";
        imageDigest = "${ZAC_IMAGE_DIGEST}";
        sha256 = "${ZAC_SHA256}";
      });
    };
  };
}
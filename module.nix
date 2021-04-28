{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.funkwhale;

  pyjwt' = pkgs.python3Packages.pyjwt.overridePythonAttrs (oldAttrs: rec {
    version = "1.7.1";
    src = oldAttrs.src.override {
      inherit version;
      sha256 =
        "8d59a976fb773f3e6a39c85636357c4f0e242707394cadadd9814f5cbaa20e96";
    };
  });

  funkwhale-python-packages = python-packages:
    with python-packages; [
      django-cacheops
      aioredis
      aiohttp
      arrow
      autobahn
      av
      bleach
      boto3
      celery
      channels
      channels-redis
      click
      django_2
      django-allauth
      django-auth-ldap
      django-oauth-toolkit
      django-cleanup
      django-cors-headers
      django-dynamic-preferences
      django_environ
      django-filter
      django_redis
      django-rest-auth
      djangorestframework
      (djangorestframework-jwt.overridePythonAttrs (oldAttrs: rec {
        propagatedBuildInputs = with pkgs.python3Packages; [
          pyjwt'
          django
          djangorestframework
        ];
      }))
      django-storages
      django_taggit
      django-versatileimagefield
      feedparser
      gunicorn
      kombu
      ldap
      markdown
      mutagen
      musicbrainzngs
      pillow
      pendulum
      persisting-theory
      psycopg2
      pyacoustid
      pydub
      PyLD
      pymemoize
      pyopenssl
      python_magic
      pytz
      redis
      requests
      (requests-http-signature.overridePythonAttrs (oldAttrs: rec {
        propagatedBuildInputs = with pkgs.python3Packages; [
          cryptography
          requests
        ];
      }))
      service-identity
      unidecode
      unicode-slugify
      uvicorn
      watchdog
    ];

  pythonEnv = pkgs.python3.buildEnv funkwhale-python-packages {
    ignoreCollisions = true;
  };

  databaseUrl =
    "postgresql:///${cfg.database.name}?host=${cfg.database.socket}";

  funkwhaleEnvironment = [
    "FUNKWHALE_URL=${cfg.hostname}"
    "FUNKWHALE_HOSTNAME=${cfg.hostname}"
    "FUNKWHALE_PROTOCOL=${cfg.protocol}"
    "EMAIL_CONFIG=${cfg.emailConfig}"
    "DEFAULT_FROM_EMAIL=${cfg.defaultFromEmail}"
    "REVERSE_PROXY_TYPE=nginx"
    "DATABASE_URL=${databaseUrl}"
    "CACHE_URL=redis://localhost:${toString config.services.redis.port}/0"
    "MEDIA_ROOT=${cfg.api.mediaRoot}"
    "STATIC_ROOT=${cfg.api.staticRoot}"
    "DJANGO_SECRET_KEY=${cfg.api.djangoSecretKey}"
    "MUSIC_DIRECTORY_PATH=${cfg.musicPath}"
    "MUSIC_DIRECTORY_SERVE_PATH=${cfg.musicPath}"
    "FUNKWHALE_FRONTEND_PATH=${cfg.dataDir}/front"
    "FUNKWHALE_PLUGINS=funkwhale_api.contrib.scrobbler"
  ];

  funkwhaleEnvFileData = builtins.concatStringsSep "\n" funkwhaleEnvironment;
  funkwhaleEnvScriptData = builtins.concatStringsSep " " funkwhaleEnvironment;

  funkwhaleEnvFile = pkgs.writeText "funkwhale.env" funkwhaleEnvFileData;
  funkwhaleEnv = { ENV_FILE = "${funkwhaleEnvFile}"; };

  funkwhaleManageScript = pkgs.writeShellScriptBin "funkwhale-manage"
    "${funkwhaleEnvScriptData} ${pythonEnv.interpreter} ${pkgs.funkwhale}/api/manage.py";

in {

  options.services.funkwhale = {
    enable = mkEnableOption "funkwhale";

    user = mkOption {
      type = types.str;
      default = "funkwhale";
      description = "funkwhale user";
    };

    group = mkOption {
      type = types.str;
      default = "funkwhale";
      description = "funkwhale group";
    };

    database = {

      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "database host";
      };

      port = mkOption {
        type = types.int;
        default = 5432;
        description = "database port";
      };

      name = mkOption {
        type = types.str;
        default = "funkwhale";
        description = "database name";
      };

      user = mkOption {
        type = types.str;
        default = "funkwhale";
        description = "database user";
      };

      password = mkOption {
        type = types.str;
        default = "";
        description = "database user's password";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "file containing the database user's password";
      };

      socket = mkOption {
        type = types.nullOr types.path;
        default = "/run/postgresql";
        description = "path to the postgresql unix socket file";
      };

    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/funkwhale";
      description = "funkwhale data directory";
    };

    apiIp = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "funkwhale API IP";
    };

    webWorkers = mkOption {
      type = types.int;
      default = 4;
      description = "number of funkwhale web workers";
    };

    apiPort = mkOption {
      type = types.port;
      default = 5000;
      description = "funkwhale API port";
    };

    hostname = mkOption {
      type = types.str;
      description = "public domain for the instance";
      example = "funkwhale.example.com";
    };

    protocol = mkOption {
      type = types.enum [ "http" "https" ];
      default = "https";
      description = "web protocol";
    };

    forceSSL = mkOption {
      type = types.bool;
      default = true;
      description = "force ssl for the web frontend";
    };

    emailConfig = mkOption {
      type = types.str;
      default = "consolemail://";
      description = ''
        email config. see <link xlink:href="https://docs.funkwhale.audio/configuration.html#email-config"/>.'';
      example = "smtp+ssl://user@:password@email.host:465";
    };

    defaultFromEmail = mkOption {
      type = types.str;
      description = "email address for system emails";
      example = "funkwhale@example.com";
    };

    api = {
      mediaRoot = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/media";
        description = "where media files are stored";
      };

      staticRoot = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/static";
        description = "where static files are stored";
      };

      djangoSecretKey = mkOption {
        type = types.str;
        description =
          "django secret key. generate one using <command>openssl rand -base64 45</command>";
      };
    };

    musicPath = mkOption {
      type = types.str;
      default = "${cfg.dataDir}/music";
      description = "directory where music is stored";
    };

  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ funkwhaleManageScript ];

    users.users.funkwhale = mkIf (cfg.user == "funkwhale") {
      group = cfg.group;
      isSystemUser = true;
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [{
        name = cfg.database.user;
        ensurePermissions = {
          "DATABASE ${cfg.database.name}" = "ALL PRIVILEGES";
        };
      }];
    };

    services.redis.enable = true;

    services.nginx = {
      enable = true;
      appendHttpConfig = ''
        upstream funkwhale-api {
          server ${cfg.apiIp}:${toString cfg.apiPort};
        }
      '';
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      virtualHosts = let withSSL = cfg.protocol == "https";
      in {
        "${cfg.hostname}" = {
          enableACME = withSSL;
          forceSSL = cfg.forceSSL;
          root = "${cfg.dataDir}/front";
          locations = {
            "/" = { proxyPass = "http://funkwhale-api/"; };
            "/front/" = { alias = "${cfg.dataDir}/front/"; };
            "= /front/embed.html" = {
              alias = "${cfg.dataDir}/front/embed.html";
            };
            "/federation/" = {
              proxyPass = "http://funkwhale-api/federation/";
            };
            "/rest/" = {
              proxyPass = "http://funkwhale-api/api/subsonic/rest/";
            };
            "/.well-known/" = {
              proxyPass = "http://funkwhale-api/.well-known/";
            };
            "/media/" = { alias = "${cfg.api.mediaRoot}/"; };
            "/_protected/media/" = {
              extraConfig = ''
                internal;
              '';
              alias = "${cfg.musicPath}/";
            };
            "/staticfiles/" = { alias = "${cfg.api.staticRoot}/"; };
          };
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.api.mediaRoot} 0755 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.api.staticRoot} 0755 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.musicPath} 0755 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.targets.funkwhale = {
      description = "funkwhale";
      wants = [
        "funkwhale-server.service"
        "funkwhale-worker.service"
        "funkwhale-beat.service"
      ];
    };

    systemd.services = let
      serviceConfig = {
        User = "${cfg.user}";
        WorkingDirectory = "${pkgs.funkwhale}/api";
      };
    in {

      funkwhale-psql-init = {
        description = "prepare funkwhale database";
        after = [ "redis.service" "postgresql.service" ];
        wantedBy = [ "funkwhale-init.service" ];
        before = [ "funkwhale-init.service" ];
        serviceConfig = {
          User = "postgres";
          ExecStart = ''
            ${config.services.postgresql.package}/bin/psql -d ${cfg.database.name} -c 'CREATE EXTENSION IF NOT EXISTS "unaccent";CREATE EXTENSION IF NOT EXISTS "citext";' '';
        };
      };

      funkwhale-init = {
        description = "funkwhale initialization";
        wantedBy = [
          "funkwhale-server.service"
          "funkwhale-worker.service"
          "funkwhale-beat.service"
        ];
        before = [
          "funkwhale-server.service"
          "funkwhale-worker.service"
          "funkwhale-beat.service"
        ];
        environment = funkwhaleEnv;
        serviceConfig = {
          User = "${cfg.user}";
          Group = "${cfg.group}";
        };
        script = ''
          ${pythonEnv.interpreter} ${pkgs.funkwhale}/api/manage.py migrate
          ${pythonEnv.interpreter} ${pkgs.funkwhale}/api/manage.py collectstatic --no-input

          if ! test -e ${cfg.dataDir}/config; then
            mkdir -p ${cfg.dataDir}/config
            ln -s ${funkwhaleEnvFile} ${cfg.dataDir}/config/.env
            ln -s ${funkwhaleEnvFile} ${cfg.dataDir}/.env
          fi
          if ! test -e ${cfg.dataDir}/front; then
            cp -r ${pkgs.funkwhale-frontend} ${cfg.dataDir}/front
          fi
        '';
      };

      funkwhale-server = {
        description = "funkwhale application server";
        partOf = [ "funkwhale.target" ];

        serviceConfig = serviceConfig // {
          ExecStart = "${pythonEnv}/bin/gunicorn config.asgi:application -w ${
              toString cfg.webWorkers
            } -k uvicorn.workers.UvicornWorker -b ${cfg.apiIp}:${
              toString cfg.apiPort
            }";
        };

        environment = funkwhaleEnv;

        wantedBy = [ "multi-user.target" ];
      };

      funkwhale-worker = {
        description = "funkwhale celery worker";
        partOf = [ "funkwhale.target" ];

        serviceConfig = serviceConfig // {
          RuntimeDirectory = "funkwhaleworker";
          ExecStart =
            "${pythonEnv}/bin/celery -A funkwhale_api.taskapp worker -l INFO";
        };

        environment = funkwhaleEnv;

        wantedBy = [ "multi-user.target" ];
      };

      funkwhale-beat = {
        description = "funkwhale celery beat process";
        partOf = [ "funkwhale.target" ];

        serviceConfig = serviceConfig // {
          RuntimeDirectory = "funkwhalebeat";
          ExecStart = ''
            ${pythonEnv}/bin/celery -A funkwhale_api.taskapp beat -l INFO --schedule="/run/funkwhalebeat/celerybeat-schedule.db" --pidfile="/run/funkwhalebeat/celerybeat.pid"'';
        };

        environment = funkwhaleEnv;

        wantedBy = [ "multi-user.target" ];
      };

    };

    meta.maintainers = with lib.maintainers; [ critbase ];

  };

}

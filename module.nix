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

  pythonEnv = let
    packageOverrides = self: super: {
      pyjwt = super.pyjwt.overridePythonAttrs (old: rec {
        version = "1.7.1";
        src = old.src.override {
          inherit version;
          sha256 =
            "8d59a976fb773f3e6a39c85636357c4f0e242707394cadadd9814f5cbaa20e96";
        };
      });
    };
  in (pkgs.python3.override { inherit packageOverrides; }).withPackages (ps: [

    ps.django-cacheops
    ps.aioredis
    ps.aiohttp
    ps.arrow
    ps.autobahn
    ps.av
    ps.bleach
    ps.boto3
    ps.celery
    ps.channels
    ps.channels-redis
    ps.click
    ps.django_2
    ps.django-allauth
    ps.django-auth-ldap
    ps.django-oauth-toolkit
    ps.django-cleanup
    ps.django-cors-headers
    ps.django-dynamic-preferences
    ps.django_environ
    ps.django-filter
    ps.django_redis
    ps.django-rest-auth
    ps.djangorestframework
    (ps.djangorestframework-jwt.overridePythonAttrs (oldAttrs: rec {
      propagatedBuildInputs = with pkgs.python3Packages; [
        pyjwt'
        django
        djangorestframework
      ];
    }))
    ps.django-storages
    ps.django_taggit
    ps.django-versatileimagefield
    ps.feedparser
    ps.gunicorn
    ps.kombu
    ps.ldap
    ps.markdown
    ps.mutagen
    ps.musicbrainzngs
    ps.pillow
    ps.pendulum
    ps.persisting-theory
    ps.psycopg2
    ps.pyacoustid
    ps.pydub
    ps.PyLD
    ps.pymemoize
    ps.pyopenssl
    ps.python_magic
    ps.pytz
    ps.redis
    ps.requests
    (ps.requests-http-signature.overridePythonAttrs (oldAttrs: rec {
      propagatedBuildInputs = with pkgs.python3Packages; [
        cryptography
        requests
      ];
    }))
    ps.service-identity
    ps.unidecode
    ps.unicode-slugify
    ps.uvicorn
    ps.watchdog
  ]);

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

  funkwhaleManageScript = pkgs.writeShellScriptBin "funkwhale-manage" ''
    ${funkwhaleEnvScriptData} ${pythonEnv.interpreter} ${pkgs.funkwhale}/api/manage.py "$@"'';

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

    environment.systemPackages = with pkgs; [ funkwhaleManageScript ffmpeg ];

    users.users.funkwhale = mkIf (cfg.user == "funkwhale") {
      group = cfg.group;
      isSystemUser = true;
    };

    users.groups.funkwhale = mkIf (cfg.group == "funkwhale") { };

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
      upstreams = {
        "funkwhale-api" = {
          servers = { "${cfg.apiIp}:${toString cfg.apiPort}" = { }; };
        };
      };
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      virtualHosts = let
        proxyConfig = ''
          proxy_set_header X-Forwarded-Host $host:$server_port;
          proxy_set_header X-Forwarded-Port $server_port;
          proxy_redirect off;
        '';
        withSSL = cfg.protocol == "https";
      in {
        "${cfg.hostname}" = {
          enableACME = withSSL;
          forceSSL = cfg.forceSSL;
          root = "${cfg.dataDir}/front";
          locations = {
            "/" = {
              proxyPass = "http://funkwhale-api/";
              proxyWebsockets = true;
              extraConfig = proxyConfig;
            };
            "/front/" = {
              alias = "${cfg.dataDir}/front/";
              extraConfig = ''
                add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; object-src 'none'; media-src 'self' data:";
                add_header Referrer-Policy "strict-origin-when-cross-origin";
                add_header Serice-Worker-Allowed "/";
                add_header X-Frame-Options "SAMEORIGIN";
                expires 30d;
                add_header Pragma public;
                add_header Cache-Control "public, must-revalidate, proxy-revalidate";
              '';
            };
            "= /front/embed.html" = {
              alias = "${cfg.dataDir}/front/embed.html";
              extraConfig = ''
                add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; object-src 'none'; media-src 'self' data:";
                add_header Referrer-Policy "strict-origin-when-cross-origin";

                add_header X-Frame-Options "ALLOW";
                expires 30d;
                add_header Pragma public;
                add_header Cache-Control "public, must-revalidate, proxy-revalidate";
              '';
            };
            "/federation/" = {
              proxyPass = "http://funkwhale-api/federation/";
              proxyWebsockets = true;
              extraConfig = proxyConfig;
            };
            "/rest/" = {
              proxyPass = "http://funkwhale-api/api/subsonic/rest/";
              proxyWebsockets = true;
              extraConfig = proxyConfig;
            };
            "/.well-known/" = {
              proxyPass = "http://funkwhale-api/.well-known/";
              proxyWebsockets = true;
              extraConfig = proxyConfig;
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

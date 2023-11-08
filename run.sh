#!/bin/bash

set -e

cd /opt/youtrack

hasArgument() {
    ARG=$1
    shift
    EXACT=$1
    shift
    while [ "$*" != "" ]; do
        if [[ "$EXACT" -eq 1 ]]; then
            [[ "$1" == "$ARG" ]] && return 0
        else
            [[ "$1" == "$ARG"* && "$1" != "$ARG" ]] && return 0
        fi
        shift
    done
    return 1
}

# Calls product 'run' command adding one-time-parameters if any was previously set by command 'configure-next-start'.
# Passed command line parameters may contain leading word 'run' or may not
run() {
    if [[ "$1" == "run" ]] ; then
        shift
    fi

    checkVolumes "run"

    ONE_TIME_PARAMS=""
    [[ -e /opt/youtrack/conf/internal/.one-time-parameters ]] \
        && ONE_TIME_PARAMS=$(</opt/youtrack/conf/internal/.one-time-parameters) \
        && rm /opt/youtrack/conf/internal/.one-time-parameters
    exec /bin/bash ./bin/youtrack.sh run "$@" $ONE_TIME_PARAMS
}

# echo warning if non-anonymous volume has not been mapped
checkVolumes() {
    if [[ -e /opt/youtrack/conf/internal/inside.container.conf.marker ]] ; then
        echo >&2 "=== WARNING! WARNING! WARNING! ========================================================================== (start warning)"
        echo >&2 "Non-anonymous volume should has been mapped to folder /opt/youtrack/conf inside container in non-demo environment."
        if [[ "$1" == "configure" ]] ; then
            echo >&2 "Otherwise defined configuration parameters would be stored to the container anonymous volume only "
            echo >&2 "and won't be applied to the next product run performed in a separate container "
        elif [[ "$1" == "run"  ]] ; then
            echo >&2 "(as well as non-anonymous volumes to directories /opt/youtrack/data, /opt/youtrack/logs and /opt/youtrack/backups)."
            echo >&2 "Otherwise, application data previously stored outside container on host machine (if any) is ignored. "
            echo >&2 "Changes made to configuration parameters and application data during this run would be applied to the container anonymous volume only "
            echo >&2 "and won't be reused if product will be run in a separate container "
            echo >&2 "(after existing container was recreated - either for normal run or for upgrade)."
        fi
        echo >&2 "See help for more details on what directories inside container should be mapped as non-anonymous volumes and why"
        echo >&2 "=========================================================================================================== (end warning)"
    fi
}

# Calls product configure command if passed command line contains at least one argument.
# Passed command line parameters may contain leading word 'configure' or may not.
configure() {
    if [[ "$1" == "configure" ]] ; then
        shift
    fi
    if [[ "$*" == "" ]] ; then
        echo "No parameters were passed, configuration phase is skipped"
    elif [ -e /not-mapped-to-volume-dir/.docker.configured ] ; then
        echo "Configuration is skipped, file /not-mapped-to-volume-dir/.docker.configured exists already"
        return 0
    else
        ATTEMPT_TO_CHANGE_DIR=0
        (hasArgument "--data-dir" 0 "$@") && echo "Data directory inside container is /opt/youtrack/data, it could not be changed" && ATTEMPT_TO_CHANGE_DIR=1
        (hasArgument "--logs-dir" 0 "$@") && echo "Logs directory inside container is /opt/youtrack/logs, it could not be changed" && ATTEMPT_TO_CHANGE_DIR=1
        (hasArgument "--backups-dir" 0 "$@") && echo "Backups directory inside container is /opt/youtrack/backups, it could not be changed" && ATTEMPT_TO_CHANGE_DIR=1
        (hasArgument "--temp-dir" 0 "$@") && echo "Temp directory inside container is /opt/youtrack/temp, it could not be changed" && ATTEMPT_TO_CHANGE_DIR=1
        [[ ATTEMPT_TO_CHANGE_DIR -eq 1 ]] && exit 1

        checkVolumes "configure"

        /bin/bash ./bin/youtrack.sh configure "$@"
        if hasArgument "--debug" 1 "$@" ; then
            echo "$@"
            echo "Passed parameters were applied to product"
            echo "File /not-mapped-to-volume-dir/.docker.configured was created (it is assumed that folder /not-mapped-to-volume-dir isn't mapped to any volume)"
            echo "All subsequent container restarts will skip configuration phase unless file /not-mapped-to-volume-dir/.docker.configured is removed"
        fi
        touch /not-mapped-to-volume-dir/.docker.configured
        echo "$@" > /not-mapped-to-volume-dir/.docker.configured
    fi
    return 0
}

case "$1" in
    bash)
        exec /bin/bash
        ;;
    help)
        echo >&2 "Available commands:"
        echo >&2 "==================="
        echo >&2 "1) help "
        echo >&2 "     Prints this help message"
        echo >&2 ""
        echo >&2 "2) configure <argument1> <argument2> ..."
        echo >&2 "     Configures properties and JVM options of a service and exits."
        echo >&2 "     It is assumed that appropriate volumes mapping is provided to this configure call. Resulted configuration is persisted to folder"
        echo >&2 "     /opt/youtrack/conf inside container. Later updated config data should be available (via volume) to another container started with 'run' command."
        echo >&2 "     See section 'Application data' below for more details."
        echo >&2 "     Arguments can be the following:"
        echo >&2 "       --<property name>=<property value>"
        echo >&2 "         changes the value of the specified property"
        echo >&2 "       -J<JVM option>"
        echo >&2 "         adds the specified JVM option"
        echo >&2 "       --debug"
        echo >&2 "         enables debug product output"
        echo >&2 ""
        echo >&2 "3) run"
        echo >&2 "     Runs the service, by default starts Configuration Wizard on the first product start"
        echo >&2 ""
        echo >&2 "4) <empty command line> "
        echo >&2 "     Works the same as 'run' command"
        echo >&2 ""
        echo >&2 "5) configure-next-start <argument1> <argument2> ..."
        echo >&2 "     Configures JVM options that will be applied to the next service start only and exits. This might be used for one-time activities, for instance, restoring password."
        echo >&2 "     Arguments can be the following:"
        echo >&2 "       --J<JVM option>"
        echo >&2 "         specified JVM option will be applied to the next start of the product (either container restart or startup of new container on the same volume)"
        echo >&2 ""
        echo >&2 " Application data"
        echo >&2 " ================"
        echo >&2 "     Product stores its application data in several folders inside container:  /opt/youtrack/data, /opt/youtrack/conf, /opt/youtrack/logs and /opt/youtrack/backups"
        echo >&2 "     By default all those directories are mapped to anonymous volumes and thus are stored by docker engine on host machine and could be found with help of docker inspect command"
        echo >&2 "     However, it is strongly recommended to use either data volume container or volume explicitly mapped to host machine file system for all directories above."
        echo >&2 "     Otherwise application data will be lost after container and its anonymous volumes were occasionally removed."
        echo >&2 ""
        echo >&2 " Configuring product"
        echo >&2 " ==================="
        echo >&2 "     Product could be run without any pre-configuration with default parameters on container's port 8080."
        echo >&2 "     Use -p <port on host machine>:8080 option of 'docker run' command to map the port."
        echo >&2 "     Use parameter --listen-port in order to override default port 8080 used by application inside docker container "
        echo >&2 "     For instance,"
        echo >&2 "       docker run <-v ...> <image> configure --listen-port=8081"
        echo >&2 "       docker run <-v ...>  -p <port on host machine>:8081 <image>"
        echo >&2 "     (it might be needed to override listen port if container is run in the host machine network (parameter --net=host is set) and port 8080 has been already occupied on host)"
        echo >&2 "     By default, the service starts the Configuration Wizard. "
        echo >&2 "     Run 'configure' command with argument '-J-Ddisable.configuration.wizard.on.clean.install=true' in order to disable Configuration Wizard."
        echo >&2 "     In that case (no Wizard), please set parameter base-url (the URL end users access service by)"
        echo >&2 "     'configure' applies all passed parameters to product configuration stored in /opt/youtrack/conf and exits."
        echo >&2 "     This way parameters are persistent and will be applied to all subsequent product runs"
        ;;
    java)
        exec /bin/bash ./bin/youtrack.sh "$@"
        ;;
    configure-next-start)
        shift
        for arg in "$@"
        do
            if [[ "$arg" != "--J"* && "$arg" != "--debug" ]]; then
                echo >&2 "ERROR! One time argument should start from --J (also is allowed --debug too)"
                exit 1
            fi
        done
        touch /opt/youtrack/conf/internal/.one-time-parameters
        echo "$@"
        echo "Parameters will be applied to the next youtrack start only"
        echo "Stored at conf volume in file /opt/youtrack/conf/internal/.one-time-parameters"
        echo "$@" > /opt/youtrack/conf/internal/.one-time-parameters
        ;;
    run)
        run "$@"
        ;;
    configure)
        configure "$@"
        ;;
    *)
        if [[ "$1" != "" && ("$1" != "--debug" || "$#" > 1 ) ]]; then
            # Some parameters are set, configure is required
            if [[ "$1" != "-"* ]]; then
                echo "Unexpected command $1, execute docker run <image> help in order to see all available commands"
                exit 1
            fi

            if [[ "$1" == "--allow.configure.and.run"* ]]; then
              shift
              configure "$@"

              EXTRA_RUN_PARAMS=""
              (hasArgument "--debug" 1 "$@") && EXTRA_RUN_PARAMS="--debug"
              run $EXTRA_RUN_PARAMS
            else
              echo "Parameters $@ could not be passed directly to command line. "
              echo "Please call 'docker run <volumes> <Image> configure' command for setting product properties (<volumes> - volumes mapped to product application data directories) and then run the product on the same volumes. Run 'docker run <Image> help' for more details"
              exit 1
            fi
        else
            run "$@"
        fi
        ;;
esac


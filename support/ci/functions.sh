# shellcheck shell=bash

DMDK_CHECKOUT_PATH="$(pwd)/documodel-development-kit"

init() {
  # shellcheck disable=SC1090
  source "${HOME}"/.bash_profile
  gem install -N bundler:1.17.3
  cd gem || exit
  gem build documodel-development-kit.gemspec
  gem install documodel-development-kit-*.gem
  dmdk init "${DMDK_CHECKOUT_PATH}"
}

checkout() {
  cd "${DMDK_CHECKOUT_PATH}" || exit
  git remote set-url origin "${CI_REPOSITORY_URL}"
  git fetch
  git checkout "${1}"
}

install() {
  cd "${DMDK_CHECKOUT_PATH}" || exit
  netstat -lpt
  echo "> Installing DMDK.."
  dmdk install shallow_clone=true
  support/set-gitlab-upstream
}

update() {
  cd "${DMDK_CHECKOUT_PATH}" || exit
  netstat -lpt
  echo "> Updating DMDK.."
  # we use `make update` instead of `dmdk update` to ensure the working directory
  # is not reset to master.
  make update
  support/set-documodel-upstream
  restart
}

start() {
  cd "${DMDK_CHECKOUT_PATH}" || exit
  killall node || true
  echo "> Starting up DMDK.."
  dmdk start
}

restart() {
  cd "${DMDK_CHECKOUT_PATH}" || exit
  dmdk stop || true
  dmdk start
}

doctor() {
  cd "${DMDK_CHECKOUT_PATH}" || exit
  echo "> Running dmdk doctor.."
  dmdk doctor
}

wait_for_boot() {
  echo "> Waiting 90 secs to give DMDK a chance to boot up.."
  sleep 90
}

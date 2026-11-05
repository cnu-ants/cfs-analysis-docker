# cFS Analysis Docker

NASA cFS (`v7.0.2-rc1-oss`) 빌드 및 정적분석을 위한 Docker Compose 환경이다. cFS, IKOS, Infer를 각각 독립된 컨테이너로 실행한다.

- **cFS:** Ubuntu 24.04, GCC 13.3, Clang/LLVM 18
- **IKOS:** 3.2, Clang/LLVM 14
- **Infer:** 1.3.0 (Linux AMD64 전용)

## 시작

Docker와 Docker Compose가 필요하다. `--arch arm64` 대신 `--arch amd64`도 사용할 수 있다.

```bash
./cfs.sh --arch arm64 build all
./cfs.sh --arch arm64 start all
./cfs.sh --arch arm64 verify all
./cfs.sh --arch arm64 smoke
```

## cFS만 빌드

분석기 없이 cFS 이미지만 빌드하려면:

```bash
./cfs.sh --arch arm64 build cfs
```

## cFS 분석

분석기는 공통 `/cFS`를 읽기 전용으로 사용하고, 각자의 `/analysis-work/cFS`에서 빌드한다.

**IKOS**

```bash
./cfs.sh --arch arm64 prepare ikos

docker exec -it cfs-arm64-ikos-1 bash -lc '
  set -e
  cd /analysis-work/cFS
  export CCC_OVERRIDE_OPTIONS="# +-Wno-error"
  ikos-scan make native_std.prep
  ikos-scan make native_std.install
'
```

**Infer (CPU1)**

```bash
./cfs.sh --arch arm64 prepare infer

docker exec cfs-arm64-infer-1 bash -lc '
  set -e
  cd /analysis-work/cFS
  make native_std.prep
  make native_std.install
  infer run -o /results/cfs-cpu1 \
    --compilation-database \
    build-native_std/native/default_cpu1/compile_commands.json
'
```

## 결과 및 종료

분석 결과는 호스트의 `results/ikos/<arch>/`, `results/infer/<arch>/`에 저장된다. cFS 테스트 로그는 `results/cfs/`에 저장된다.

```bash
./cfs.sh --arch arm64 stop
```

`stop`은 컨테이너만 내리며 Docker 이미지와 작업 볼륨은 유지한다. Apple Silicon에서는 Infer가 AMD64 에뮬레이션으로 실행된다.

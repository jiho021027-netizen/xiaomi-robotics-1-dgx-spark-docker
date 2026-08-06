# DGX Spark RoboCasa365 image

**This configuration has only been written; Docker build/run validation has not been performed.** It targets Linux ARM64 DGX Spark (GB10), CUDA 13.0, and the checked-in XR-1 SDPA grid-metadata policy.

## Build

Use `/home/edgexpert01/projects/Xiaomi-Robotics-1` as the build context:

```bash
cd /home/edgexpert01/projects/Xiaomi-Robotics-1
docker build \
  -f docker/Dockerfile.dgx-spark-robocasa365 \
  --build-arg APP_UID="$(id -u)" \
  --build-arg APP_GID="$(id -g)" \
  --build-arg 'PYTORCH_ARM64_INSTALL_COMMAND=<verified command that installs torch==2.7.0+cu128 into both /opt/venvs/xr1-server and /opt/venvs/robocasa365-client>' \
  -t xr1-robocasa365:dgx-spark .
```

The host environment confirms PyTorch `2.7.0+cu128`, but does not record a usable ARM64 package index or wheel URL. No index URL is guessed here; obtain and validate that command before building.

## Runtime mounts

The image deliberately excludes checkpoint weights, RoboCasa assets, caches, results, venvs, Git history, and MP4s. Mount them instead:

| Container path | Host content |
|---|---|
| `/models/Xiaomi-Robotics-1-RoboCasa365` | checkpoint directory |
| `/opt/robocasa/robocasa/models/assets` | RoboCasa assets directory |
| `/cache/huggingface` | writable Hugging Face cache |
| `/cache/numba` | writable Numba cache |
| `/results` | evaluation output directory |

Run containers with the same numeric UID/GID as the host so cache and result files remain host-owned.

## Server

```bash
docker run --rm --gpus all --network host --ipc host --shm-size=16g \
  -v "$PWD/checkpoints/Xiaomi-Robotics-1-RoboCasa365:/models/Xiaomi-Robotics-1-RoboCasa365:ro" \
  -v /path/to/robocasa-assets:/opt/robocasa/robocasa/models/assets:ro \
  -v /path/to/hf-cache:/cache/huggingface \
  -v /path/to/numba-cache:/cache/numba \
  xr1-robocasa365:dgx-spark server
```

The foreground server is PID 1, listens on `0.0.0.0:10086`, uses `XR1_ATTN_IMPL=sdpa`, and keeps `image_grid_thw` / `video_grid_thw` on contiguous CPU tensors.

## Evaluator

Start the server first. The evaluator joins host networking and therefore uses `SERVER_ADDR=127.0.0.1` and `BASE_PORT=10086`.

```bash
docker run --rm --gpus all --network host --ipc host --shm-size=16g \
  -e SERVER_ADDR=127.0.0.1 -e BASE_PORT=10086 -e NUM_TRIALS=1 \
  -v "$PWD/checkpoints/Xiaomi-Robotics-1-RoboCasa365:/models/Xiaomi-Robotics-1-RoboCasa365:ro" \
  -v /path/to/robocasa-assets:/opt/robocasa/robocasa/models/assets:ro \
  -v /path/to/hf-cache:/cache/huggingface \
  -v /path/to/numba-cache:/cache/numba \
  -v /path/to/results:/results \
  xr1-robocasa365:dgx-spark eval --task-name CloseBlenderLid --save-videos
```

This is a one-episode CloseBlenderLid video example. Pass any normal `scripts/launch_robocasa365.sh` evaluator arguments after `eval`; the entrypoint does not impose task, seed, or horizon choices.

For atomic comparisons, first align the WorldDreamer/RLDX episode manifest, split, per-task official horizon, reset-seed sequence, action-step count, and observation history. Do not treat this generic example as a matched atomic protocol.

## Provenance and limitations

- Base image: `nvcr.io/nvidia/cuda:13.0.1-devel-ubuntu24.04` (`linux/arm64`).
- Python is installed as `3.10.20` with `uv`; server and client remain separate venvs.
- RoboCasa is cloned at `be22d659b02db8f6d7f3a3c3edc742934fdcbaae`; robosuite at `85abee228d1c43ab1939bce33028099945d453b4`.
- Host RoboCasa has uncommitted changes, so this image reproduces only the recorded commit, not those local modifications.
- FlashAttention 2 is intentionally unused. SDPA plus the XR-1 grid metadata CPU policy is required on GB10.
- A GB10 has unified memory; concurrent GPU processes can still cause OOM.
- The image itself has not been built or run. The ARM64 PyTorch installation command remains **TODO / confirmation required**.

# Actually build from the Dockerfile in the root of the kubespray repo.
# docker build -t thinkcentre-kubespray:v2.19.0 .
docker run --rm -it --mount type=bind,source="$(pwd)",dst=/thinkcentreansible --mount type=bind,source="${HOME}"/.ssh/id_ed25519,dst=/root/.ssh/id_ed25519 thinkcentre-kubespray:v2.19.0 bash

FROM public.ecr.aws/sam/build-python3.12:latest

RUN python3 -m pip install --no-cache-dir uv

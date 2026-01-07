# Use AWS Lambda Python base image
# This image includes the Lambda Runtime API that talks to AWS
FROM public.ecr.aws/lambda/python:3.11

# Copy requirements first (Docker layer caching - faster rebuilds)
COPY app/requirements.txt ${LAMBDA_TASK_ROOT}/

# Install Python dependencies
# --no-cache-dir = don't save downloaded packages (smaller image)
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ${LAMBDA_TASK_ROOT}/

# Set the Lambda handler
# Format: filename.function_name
# This tells Lambda to call lambda_handler() in lambda_handler.py
CMD ["lambda_handler.lambda_handler"]
```

**What's Special About This:**
1. Uses AWS's official Lambda base image (pre-configured)
2. `LAMBDA_TASK_ROOT` is a special directory Lambda expects
3. `CMD` tells Lambda which function to call
4. No EXPOSE or HEALTHCHECK needed (Lambda handles this)

---

## File: `.dockerignore`
```
# Don't include these in the Docker image (keeps it small and fast)
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
.pytest_cache/
.venv/
venv/
.git/
.github/
terraform/
tests/
*.md
.gitignore
.DS_Store
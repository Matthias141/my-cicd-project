FROM public.ecr.aws/lambda/python:3.11

# Update system packages to fix security vulnerabilities
# Fixes: CVE-2025-64720, CVE-2025-64505 (libpng), CVE-2025-14087 (glib2), CVE-2025-8869 (pip)
RUN yum update -y libpng glib2 python3-pip && \
    yum clean all && \
    rm -rf /var/cache/yum

# Copy requirements first to leverage Docker cache
COPY app/requirements.txt ${LAMBDA_TASK_ROOT}/

# Upgrade pip to latest version to fix CVE-2025-8869
RUN pip install --upgrade pip

# Install dependencies (including Mangum)
RUN pip install --no-cache-dir -r requirements.txt

# Copy all your code files (main.py, etc.) to the container
COPY app/ ${LAMBDA_TASK_ROOT}/

# CRITICAL CHANGE: Point to main.py and the 'handler' object we just added
CMD ["main.handler"]
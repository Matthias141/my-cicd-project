FROM public.ecr.aws/lambda/python:3.11

# Copy requirements first to leverage Docker cache
COPY requirements.txt ${LAMBDA_TASK_ROOT}/

# Install dependencies (including Mangum)
RUN pip install --no-cache-dir -r requirements.txt

# Copy all your code files (main.py, etc.) to the container
COPY . ${LAMBDA_TASK_ROOT}/

# CRITICAL CHANGE: Point to main.py and the 'handler' object we just added
CMD ["main.handler"]
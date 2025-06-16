# Self-Hosted GitHub Actions Runner
A containerised GitHub Actions runner that runs locally using Docker Compose. This setup allows you to run GitHub Actions workflows on your own infrastructure with full control over the environment and resources.

## Features
- 🐳 **Containerised**: Runs in Docker for consistency and isolation
- 🔄 **Auto-registration**: Automatically registers and deregisters with GitHub
- 🛠️ **Pre-configured**: Includes common tools (Node.js, Python, Docker CLI, etc.)
- 📊 **Resource limits**: Configurable CPU and memory constraints
- 🔒 **Secure**: Runs as non-root user with proper token management
- 🏷️ **Flexible**: Support for custom labels and both repo/org-level runners
- 💾 **Persistent**: Optional persistent storage for build artifacts

## Prerequisites
- Docker and Docker Compose installed
- GitHub Personal Access Token with appropriate permissions
- Git (for cloning this repository)

## Quick Start
1. **Clone this repository:**
   ```bash
   git clone https://github.com/homelab-bg/docker-github-runner.git
   cd docker-github-runner
   ```

2. **Create environment file:**
   ```bash
   cp .env.example .env
   ```

3. **Configure your environment:**
   Edit `.env` file with your GitHub details:
   ```bash
   GITHUB_OWNER=your-username-or-org
   GITHUB_REPOSITORY=your-repo-name  # Only needed for repo-level runners
   GITHUB_TOKEN=ghp_your_token_here
   ```

4. **Create required directories:**
   ```bash
   mkdir -p runner-data workspace
   ```

5. **Build and start the runner:**
   ```bash
   docker-compose up -d --build
   ```

6. **Verify the runner is working:**
   ```bash
   docker-compose logs -f github-runner
   ```

The runner should appear in your GitHub repository/organization settings under "Actions" > "Runners".

## Configuration
### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GITHUB_OWNER` | ✅ | - | GitHub username or organization name |
| `GITHUB_REPOSITORY` | ⚠️* | - | Repository name (required for repo-level runners) |
| `GITHUB_TOKEN` | ✅ | - | GitHub Personal Access Token |
| `RUNNER_NAME` | ❌ | `local-docker-runner` | Name for the runner |
| `RUNNER_LABELS` | ❌ | `local,docker,self-hosted` | Comma-separated labels |
| `RUNNER_GROUP` | ❌ | `default` | Runner group name |
| `RUNNER_SCOPE` | ❌ | `repo` | `repo` for repository, `org` for organization |
| `MEMORY_LIMIT` | ❌ | `300M` | Maximum memory allocation |
| `CPU_LIMIT` | ❌ | `0.3` | Maximum CPU allocation |

*Required only when `RUNNER_SCOPE=repo`

### GitHub Token Setup
#### For Repository Runners:
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes:
   - ✅ `repo`
4. Copy the token to your `.env` file

#### For Organization Runners:
1. Follow the same steps as above
2. Additional scope required:
   - ✅ `admin:org`

### Runner Scope Configuration
#### Repository-Level Runner:
```bash
RUNNER_SCOPE=repo
GITHUB_OWNER=your-username
GITHUB_REPOSITORY=your-repo-name
```

#### Organization-Level Runner:
```bash
RUNNER_SCOPE=org
GITHUB_OWNER=your-org-name
# GITHUB_REPOSITORY not needed for org runners
```

## Usage
### Starting the Runner
```bash
# Build and start in detached mode
docker-compose up -d --build

# View logs
docker-compose logs -f github-runner
```

### Stopping the Runner
```bash
# Graceful shutdown (automatically deregisters runner)
docker-compose down
```

### Rebuilding
```bash
# Rebuild the image (e.g., after Dockerfile changes)
docker-compose build --no-cache
docker-compose up -d
```

### Scaling Multiple Runners
```bash
# Run multiple instances
docker-compose up -d --scale github-runner=3
```

## Workflow Targeting
Target your self-hosted runner in GitHub Actions workflows:

```yaml
name: CI
on: [push]

jobs:
  build:
    runs-on: [self-hosted, local]  # Uses runners with 'local' label
    steps:
      - uses: actions/checkout@v4
      - name: Run on self-hosted runner
        run: echo "Running on local runner!"
```

### Available Labels
- `self-hosted` (automatically added)
- `linux` (automatically added)
- `x64` (automatically added)
- `local` (from default config)
- `docker` (from default config)
- Custom labels (configure via `RUNNER_LABELS`)

## Included Tools
The runner comes pre-installed with:

- **Languages**: Python 3, Node.js, npm
- **Build tools**: build-essential, git
- **Container tools**: Docker CLI
- **Utilities**: curl, wget, jq, unzip
- **System**: sudo access for the runner user

### Adding More Tools
Edit the `Dockerfile` to install additional tools:

```dockerfile
# Add your tools here
RUN apt-get update && apt-get install -y \
    terraform \
    kubectl \
    aws-cli \
    && rm -rf /var/lib/apt/lists/*
```

## File Structure
```
github-runner/
├── docker-compose.yml          # Main compose configuration
├── Dockerfile                  # Runner image definition
├── .env.example               # Environment template
├── .env                       # Your actual environment (gitignored)
├── README.md                  # This file
├── .gitignore                 # Git ignore rules
├── scripts/
│   ├── entrypoint.sh         # Container startup script
│   └── remove-runner.sh      # Runner cleanup script
└── runner-data/              # Persistent runner workspace (gitignored)
```

## Troubleshooting
### Runner Not Appearing in GitHub
1. Check logs: `docker-compose logs github-runner`
2. Verify `GITHUB_TOKEN` has correct permissions
3. Ensure `GITHUB_OWNER` and `GITHUB_REPOSITORY` are correct
4. Check if runner name already exists (names must be unique)

### Permission Denied Errors
```bash
# Fix script permissions
chmod +x scripts/*.sh
```

### Docker Socket Issues
```bash
# Ensure Docker socket is accessible
ls -la /var/run/docker.sock

# Add your user to docker group (Linux)
sudo usermod -aG docker $USER
```

### Memory/CPU Issues
Adjust resource limits in `.env`:
```bash
MEMORY_LIMIT=2G
CPU_LIMIT=1.0
```

### Token Expiration
- Personal Access Tokens expire - check GitHub settings
- Regenerate token if expired and update `.env`

## Security Considerations
- 🔐 Keep your `GITHUB_TOKEN` secure and never commit it
- 🔄 Rotate tokens regularly
- 🚫 Use minimum required token permissions
- 🛡️ Runner runs as non-root user
- 🔒 Consider network isolation for production use
- 📝 Monitor runner activity in GitHub Actions logs

## Advanced Configuration
### Persistent SSH Keys
For workflows that need Git access to private repositories:

1. Create SSH directory:
   ```bash
   mkdir -p ssh
   cp ~/.ssh/id_rsa ssh/
   ```

2. Uncomment SSH volume in `docker-compose.yml`:
   ```yaml
   volumes:
     - ./ssh:/home/runner/.ssh:ro
   ```

### Custom Workspace
Mount local directories for development:
```bash
LOCAL_WORKSPACE=/path/to/your/code docker-compose up -d
```

### Production Deployment
For production use, consider:
- Using Docker Swarm or Kubernetes
- Implementing proper logging and monitoring
- Setting up multiple runners for high availability
- Using secrets management solutions

# prom-release

**prom-release** is a  simple release management tool for Kubernetes environments, designed to make release and deployment workflows simple, automated, and auditable.

---

### Key Features

- **Track Every Release:**
  - Maintain a complete history of all releases for every service you run.
  - Instantly see which versions are deployed to each environment at any point in time.

- **Decouple release and source code:**
  - Let your source code govern how to build and package.
  - Decouple release and deployment management from your source code and running clusters.
  - Automate build pipelines to publish YAML files and artifacts into a centralized repository of releases.

- **Easy Promotion & Rollback:**
  - Promote releases to any environment with simple commands.
  - Roll back environments to previous versions effortlessly.

- **Environment Synchronization:**
  - Keep multiple environments aligned and in sync.
  - Audit deployment history and changes with confidence.

- **Supports Multiple Builds & Environments:**
  - Effortlessly manage releases for many services and environments.
  - Integrate with your build scripts for automated release creation and promotion.

---

### Git-Based Management

All releases and environment states managed by **prom-release** are stored in a Git repository. This approach makes it simple to track changes, collaborate with your team, and maintain a complete history of every deployment and promotion. By leveraging Git, you can easily audit changes, roll back to previous states, and synchronize environments across teams and clusters. Version control ensures that your release and deployment process is transparent, reliable, and fully integrated with your existing workflows.

> Whether you’re running a single service or a complex microservices architecture, **prom-release** gives you the control and visibility you need to manage releases and deployments with confidence.

---

### Get Started

Getting started with prom-release is simple:

1. **Create a Git repository** for your releases and environments.
2. **Copy the contents of this repository** into your new repo.
3. **Start running prom-release commands** to create builds, manage environments, and track releases.

No complex setup or dependencies, just Git and shell scripts. All release history, environment state, and changes are tracked automatically in your repository, making it easy to collaborate and audit.

> PS! Just leave your images with the :latest tag in your yaml files and prom-release will replace them with the right version

#### Version Yaml Sample
When you want to create releases from your builds you just supply a version.yaml file and the directory containing your deployment.yaml, ingress.yaml ...
```yaml
major: 1
minor: 0
```
---

### Example

Here's a simple example of how you might use prom-release to manage releases and environments:

```sh
#FYI the version.yaml file is just a yaml file with your builds major and minor version eg:
# major: 1
# minor: 0

# Create releases for a frontend
./prom.sh build create MyFrontend frontend-version.yaml ./yamls/frontend
# Create releases for a backend service
./prom.sh build create MyBackend backend-version.yaml ./yamls/backend

# Provision a new environment (e.g., dev)
./prom.sh env provision dev

# Promote the releases to the environment
./prom.sh build promote MyFrontend 1.0.0 dev
./prom.sh build promote MyBackend 1.0.0 dev

# Commit the changes
./prom.sh commit "Promoted initial version of frontend and backend to dev"
```
---

### Example usage in a build file
In the case that you'd want to use prom-release in a Github Action to create a release and then generate a container and push that to let's say Azure you would have a build file like this

```yaml
name: My Frontend Build
on:
  push:
    branches:
      - environment-dev
  pull_request:
    branches:
      - environment-dev

jobs:

  install-and-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Checkout releases repository
        uses: actions/checkout@v4
        with:
          repository: MyOrg/myprom-releases
          path: './releases'
          token: ${{ secrets.RELEASES_REPO_PAT }}

      - name: Build application
        run: |
          ./build.sh

      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Build and push Docker image
        run: |
          # Run prom.sh to create a new release
          VERSION=$(bash "releases/prom.sh" "build" "create" "OurFrontend" "./build_files/version.yaml" "./build_files/yamls")
          if [ $? -ne 0 ]; then
            exit 1
          fi

          # Build and upload the docker image for the version of the new release
          az acr login --name my_acr 
          docker build -t my_acr.azurecr.io/$APPLICATION_ID:$VERSION .
          docker push my_acr.azurecr.io/$APPLICATION_ID:$VERSION

          # And if you in addition want to auto promote the release to an environment:
          # Promote the new release to development
          releases/prom.sh build promote OurFrontend "$VERSION" dev
          if [ $? -ne 0 ]; then
            exit 1
          fi

          # Commit and push the the release information
          releases/prom.sh commit "Created release and promoted OurFrontend $VERSION"
          if [ $? -ne 0 ]; then
            exit 1
          fi
```

---

### Use in combination with ArgoCD 
ArgoCD is a great tool for handling deployments to a Kubernetes cluster. Because of the simple git repository and environment folder structure it is trivial to set up a configuration to have ArgoCD auto deploy your full environment when you commit changes with prom-release.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: all-our-great-services
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/OurOrg/our-releases
    targetRevision: HEAD
    # Path to all environmennt artifacts in your prom-release repository
    path: environments/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true 
```

---

### Basic Commands for Releases and Environments

Managing releases and environments with prom-release is designed to be simple, transparent, and robust. These commands are essential for:

- **Visibility:** Instantly see what builds and releases exist, and which versions are deployed to each environment.
- **Auditability:** Track changes and deployments over time, making it easy to review history and troubleshoot issues.
- **Automation:** Integrate with CI/CD pipelines for hands-off release and environment management.
- **Safety:** Cleanly provision, promote, and remove releases and environments, reducing risk of manual errors.

#### List all builds
Shows all builds that have been created and tracked by prom-release.
```sh
./prom.sh build list
```

#### List all releases for a build
Displays all release versions for a specific build, helping you audit and select versions for promotion or rollback.
```sh
./prom.sh build list-releases MyFrontend
```

#### List all environments
Lists all environments managed by prom-release, giving you a clear view of your deployment landscape.
```sh
./prom.sh env list
```

#### List all builds/releases in an environment
Shows which builds and versions are currently deployed in a given environment.
```sh
./prom.sh env list-builds dev
```

#### Provision a new environment
Creates a new environment and populates it with the latest releases, ensuring a consistent starting point.
```sh
./prom.sh env provision dev
```

#### Promote a release to an environment
Deploys a specific release version to an environment, making controlled rollouts and upgrades easy.
```sh
./prom.sh build promote MyFrontend 1.0.0 dev
```

#### Delete a build from an environment
Removes a build's release from an environment, useful for cleanup or rollback.
```sh
./prom.sh env delete-build dev MyFrontend
```

#### Remove an environment
Deletes an environment and all its releases, useful for decommissioning or test cleanup.
```sh
./prom.sh env rm dev
```

---

### Environment Alignment and Snapshotting

Keeping environments aligned and maintaining snapshots is critical for:

- **Consistency:** Ensure all environments (e.g., staging, dev, prod) run the same versions of services.
- **Disaster Recovery:** Restore environments to known good states after issues or failed deployments.
- **Change Tracking:** Audit and compare environment states over time.
- **Safe Rollbacks:** Quickly revert to previous configurations if needed.

#### Align one environment to match another
Synchronize all builds and versions in one environment to match another (e.g., align staging to dev). This is vital for keeping test and production environments consistent.
```sh
./prom.sh env align staging dev
```

#### List all snapshots for an environment
Shows all saved snapshots for an environment, providing restore points and audit history.
```sh
./prom.sh env list-snapshots dev
```

#### View the contents of a snapshot
Displays the builds and versions in a snapshot, helping you review or compare environment states.
```sh
./prom.sh env cat-snapshot dev 2025.07.26.12.00.00.snapshot
```

#### Restore an environment to a previous snapshot
Reverts an environment to the state captured in a snapshot, enabling safe and fast rollbacks.
```sh
./prom.sh env restore-snapshot dev 2025.07.26.12.00.00.snapshot
```

---

### Logical environment support
Logical environments in prom-release let you run multiple isolated sets of releases within a single Kubernetes cluster. Each logical environment acts as a separate namespace for your builds and releases, identified by a prefix (e.g., `feature1@dev`, `test@dev`). This enables you to:

- **Share infrastructure:** Run many parallel environments (feature branches, sandboxes, review apps) in one cluster, saving resources and cost.
- **Isolate changes:** Each logical environment has its own promoted releases, ignore list, and snapshots. Changes in one logical environment do not affect others.
- **Enable flexible workflows:** Spin up new logical environments for experiments, hotfixes, or team work, then delete them when done.

#### How logical environments work
- Logical environments are named with a prefix and base environment (e.g., `teamA@dev`).
- All release files, snapshots, and ignore lists are namespaced by this prefix.
- You can list, align, provision, snapshot, and restore logical environments independently.

#### Managing logical environments
- **List logical environments:**
  ```sh
  ./prom.sh env list-logical dev
  ```
  Shows all logical environments for a base environment (e.g., all prefixes for `dev`).

- **Provision a logical environment:**
  ```sh
  ./prom.sh env provision teamA@dev
  ```
  Creates a new logical environment, initializing it with the latest releases.

- **Promote releases in a logical environment:**
  ```sh
  ./prom.sh build promote MyFrontend 1.2.3 teamA@dev
  ```
  Promotes a release to a specific logical environment.

- **Ignore builds in a logical environment:**
  ```sh
  ./prom.sh env ignore teamA@dev add MyBackend
  ```
  Prevents a build from being promoted in a logical environment.

- **Align logical environments:**
  ```sh
  ./prom.sh env align teamA@dev dev
  ```
  Synchronizes all builds and versions in `teamA@dev` to match those in `dev`.

- **Snapshot and restore logical environments:**
  ```sh
  ./prom.sh env list-snapshots teamA@dev
  ./prom.sh env restore-snapshot teamA@dev 2025.07.26.12.00.00.snapshot
  ```
  Save and revert the state of a logical environment at any time.

Logical environments maximize cluster utilization, streamline development workflows, and maintain clean separation between different sets of releases-all with simple shell commands and Git-based tracking.

---

### Logical environment YAML naming: InsertBefore and InsertAfter

To help you manage resource naming for logical environments, prom-release supports special placeholders in your YAML files:

- `[LogicalEnvironmentInsertBefore=some-text]` - Inserts the environment prefix before every occurrence of `some-text` on that line.
- `[LogicalEnvironmentInsertAfter=some-text]` - Inserts the environment prefix after every occurrence of `some-text` on that line.

This allows you to use a single YAML source to generate environment-specific resources for multiple logical environments, ensuring that names, labels, and selectors are unique and isolated.

#### Example: InsertBefore
Suppose you have a deployment YAML like this:
```yaml
metadata:
  name: my-frontend # [LogicalEnvironmentInsertBefore=my-frontend] Frontend deployment name
```
If your logical environment prefix is `test`, the processed YAML will become:
```yaml
metadata:
  name: test-my-frontend # Frontend deployment name
```

#### Example: InsertAfter
Suppose you have a service YAML like this:
```yaml
metadata:
  name: my-backend # [LogicalEnvironmentInsertAfter=my-backend] Backend service name
```
If your logical environment prefix is `feature1`, the processed YAML will become:
```yaml
metadata:
  name: my-backend-feature1 # Backend service name
```

#### Multiple placeholders
You can use multiple placeholders in the same file to update different resource names, selectors, or labels:
```yaml
spec:
  selector:
    app: my-frontend # [LogicalEnvironmentInsertBefore=my-frontend]
    tier: backend # [LogicalEnvironmentInsertAfter=backend]
```
With prefix `teamA`, this becomes:
```yaml
spec:
  selector:
    app: teamA-my-frontend
    tier: backend-teamA
```

#### How it works
- Placeholders are processed automatically when you create a release with `build create`.
- After processing, the placeholders are removed and any empty comments are cleaned up.
- This ensures your resources are correctly namespaced for each logical environment, avoiding conflicts and enabling true multi-tenancy in a single cluster.

By using these placeholders, you can maintain a single set of YAML templates and generate environment-specific manifests for any logical environment, making your release process flexible and scalable.

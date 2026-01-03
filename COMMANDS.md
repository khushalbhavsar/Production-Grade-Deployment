# 📋 Commands Reference

## Local Development

### Python/Flask

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Install dependencies
pip install -r src/requirements.txt

# Run application locally
python src/app.py

# Run tests
python -m pytest tests/ -v
```

## Docker Commands

```bash
# Build Docker image
docker build -t shopeasy:latest -f docker/Dockerfile .

# Run container locally
docker run -p 5000:5000 shopeasy:latest

# Tag image for DockerHub
docker tag shopeasy:latest khushalbhavsar/multibranch-flask-app:latest

# Push to DockerHub
docker push khushalbhavsar/multibranch-flask-app:latest

# View running containers
docker ps

# Stop container
docker stop <container_id>
```

## Git Commands

```bash
# Create feature branch
git checkout -b featureA

# Add and commit changes
git add .
git commit -m "Add new feature"

# Push feature branch
git push origin featureA

# Merge to main (after PR approval)
git checkout main
git pull origin main
git merge featureA
git push origin main
```

## Kubernetes Commands

```bash
# Apply deployment
kubectl apply -f k8s/deployment.yaml

# Apply service
kubectl apply -f k8s/service.yaml

# Check deployment status
kubectl get deployments

# Check pods
kubectl get pods

# Check services
kubectl get services

# Get pod logs
kubectl logs <pod_name>

# Describe pod
kubectl describe pod <pod_name>

# Scale deployment
kubectl scale deployment shopeasy-app --replicas=5

# Rollback deployment
kubectl rollout undo deployment/shopeasy-app

# Delete resources
kubectl delete -f k8s/
```

## Argo CD Commands

```bash
# Login to Argo CD
argocd login <ARGOCD_SERVER>

# List applications
argocd app list

# Sync application
argocd app sync shopeasy-app

# Get application status
argocd app get shopeasy-app

# View application history
argocd app history shopeasy-app

# Rollback to previous version
argocd app rollback shopeasy-app <REVISION>
```

## AWS EKS Commands

```bash
# Update kubeconfig for EKS
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Get EKS cluster info
aws eks describe-cluster --name <cluster-name>

# List EKS clusters
aws eks list-clusters

# Get node info
kubectl get nodes
```

## Jenkins

### Pipeline Trigger (Manual)
```bash
# Trigger build via Jenkins CLI
java -jar jenkins-cli.jar -s http://JENKINS_URL build "job-name"
```

## Troubleshooting

```bash
# Check pod events
kubectl describe pod <pod_name>

# View all resources in namespace
kubectl get all -n default

# Check resource usage
kubectl top pods

# Port forward for local debugging
kubectl port-forward svc/shopeasy-service 8080:80

# Execute command in pod
kubectl exec -it <pod_name> -- /bin/bash
```

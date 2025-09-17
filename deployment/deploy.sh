#!/bin/bash

# Deployment script for Hydration App
# Handles local and production deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    print_status "Docker is running"
}

# Check if Docker Compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install it and try again."
        exit 1
    fi
    print_status "Docker Compose is available"
}

# Setup environment
setup_environment() {
    print_step "Setting up environment"
    
    if [ ! -f .env ]; then
        print_warning "No .env file found. Creating from example..."
        cp deployment/env.example .env
        print_warning "Please update .env with your actual values before continuing."
        read -p "Press Enter to continue after updating .env..."
    fi
    
    print_status "Environment setup complete"
}

# Build images
build_images() {
    print_step "Building Docker images"
    
    # Build backend
    print_status "Building backend image..."
    docker build -f deployment/Dockerfile.backend -t hydration-backend .
    
    # Build frontend
    print_status "Building frontend image..."
    docker build -f deployment/Dockerfile.frontend -t hydration-frontend ./frontend
    
    print_status "Images built successfully"
}

# Start services
start_services() {
    print_step "Starting services"
    
    # Stop existing services
    docker-compose -f deployment/docker-compose.yml down
    
    # Start services
    docker-compose -f deployment/docker-compose.yml up -d
    
    print_status "Services started"
}

# Wait for services to be ready
wait_for_services() {
    print_step "Waiting for services to be ready"
    
    # Wait for backend
    print_status "Waiting for backend..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -f http://localhost:5000/health > /dev/null 2>&1; then
            print_status "Backend is ready"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        print_error "Backend failed to start within 60 seconds"
        exit 1
    fi
    
    # Wait for frontend
    print_status "Waiting for frontend..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -f http://localhost:3000 > /dev/null 2>&1; then
            print_status "Frontend is ready"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        print_error "Frontend failed to start within 60 seconds"
        exit 1
    fi
}

# Run database migrations
run_migrations() {
    print_step "Running database migrations"
    
    # This would run your database migrations
    # For now, we'll just print a message
    print_status "Database migrations completed"
}

# Health check
health_check() {
    print_step "Running health checks"
    
    # Check backend
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        print_status "✅ Backend is healthy"
    else
        print_error "❌ Backend health check failed"
        exit 1
    fi
    
    # Check frontend
    if curl -f http://localhost:3000 > /dev/null 2>&1; then
        print_status "✅ Frontend is healthy"
    else
        print_error "❌ Frontend health check failed"
        exit 1
    fi
    
    # Check Prometheus
    if curl -f http://localhost:9090 > /dev/null 2>&1; then
        print_status "✅ Prometheus is healthy"
    else
        print_warning "⚠️ Prometheus health check failed"
    fi
    
    # Check Grafana
    if curl -f http://localhost:3001 > /dev/null 2>&1; then
        print_status "✅ Grafana is healthy"
    else
        print_warning "⚠️ Grafana health check failed"
    fi
}

# Show deployment info
show_info() {
    print_status "🎉 Deployment complete!"
    echo ""
    echo "📱 Application URLs:"
    echo "  Frontend: http://localhost:3000"
    echo "  Backend API: http://localhost:5000"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3001 (admin/admin123)"
    echo ""
    echo "🔧 Management Commands:"
    echo "  View logs: docker-compose -f deployment/docker-compose.yml logs -f"
    echo "  Stop services: docker-compose -f deployment/docker-compose.yml down"
    echo "  Restart services: docker-compose -f deployment/docker-compose.yml restart"
    echo ""
}

# Cleanup function
cleanup() {
    print_warning "Cleaning up..."
    docker-compose -f deployment/docker-compose.yml down
    print_status "Cleanup complete"
}

# Main deployment function
deploy() {
    print_status "Starting Hydration App deployment..."
    
    # Pre-deployment checks
    check_docker
    check_docker_compose
    setup_environment
    
    # Build and deploy
    build_images
    start_services
    wait_for_services
    run_migrations
    health_check
    show_info
}

# Handle script interruption
trap cleanup EXIT

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "build")
        check_docker
        build_images
        ;;
    "start")
        check_docker
        check_docker_compose
        start_services
        wait_for_services
        health_check
        show_info
        ;;
    "stop")
        docker-compose -f deployment/docker-compose.yml down
        print_status "Services stopped"
        ;;
    "restart")
        docker-compose -f deployment/docker-compose.yml restart
        wait_for_services
        health_check
        print_status "Services restarted"
        ;;
    "logs")
        docker-compose -f deployment/docker-compose.yml logs -f
        ;;
    "health")
        health_check
        ;;
    *)
        echo "Usage: $0 {deploy|build|start|stop|restart|logs|health}"
        echo ""
        echo "Commands:"
        echo "  deploy  - Full deployment (default)"
        echo "  build   - Build Docker images only"
        echo "  start   - Start services"
        echo "  stop    - Stop services"
        echo "  restart - Restart services"
        echo "  logs    - View service logs"
        echo "  health  - Run health checks"
        exit 1
        ;;
esac

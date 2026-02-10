#!/usr/bin/env python3
"""
Quick test script to verify the complete pipeline
"""
import subprocess
import sys
import os
from pathlib import Path


def print_header(text):
    """Print a formatted header"""
    print("\n" + "=" * 60)
    print(text)
    print("=" * 60 + "\n")


def run_command(cmd, description, check=True):
    """Run a shell command and report status"""
    print(f"→ {description}...")
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=check,
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(f"✓ {description} - SUCCESS")
            return True
        else:
            print(f"✗ {description} - FAILED")
            if result.stderr:
                print(f"  Error: {result.stderr[:200]}")
            return False
    except Exception as e:
        print(f"✗ {description} - ERROR: {str(e)}")
        return False


def check_file_exists(filepath, description):
    """Check if a file exists"""
    print(f"→ Checking {description}...")
    if Path(filepath).exists():
        print(f"✓ {description} exists")
        return True
    else:
        print(f"✗ {description} not found")
        return False


def main():
    """Run all verification checks"""
    print_header("MLOps Pipeline Verification")
    
    results = {}
    
    # Change to project directory
    os.chdir(Path(__file__).parent.parent)
    
    # M1: Model Development
    print_header("M1: Model Development & Experiment Tracking")
    
    results['git'] = run_command(
        "git status",
        "Git repository initialized",
        check=False
    )
    
    results['dvc'] = run_command(
        "dvc version",
        "DVC installed",
        check=False
    )
    
    results['requirements'] = check_file_exists(
        "requirements.txt",
        "Requirements file"
    )
    
    results['model_code'] = check_file_exists(
        "src/model.py",
        "Model training code"
    )
    
    # M2: Packaging
    print_header("M2: Model Packaging & Containerization")
    
    results['api'] = check_file_exists(
        "api/main.py",
        "FastAPI service"
    )
    
    results['dockerfile'] = check_file_exists(
        "Dockerfile",
        "Dockerfile"
    )
    
    results['docker'] = run_command(
        "docker --version",
        "Docker installed",
        check=False
    )
    
    # M3: Testing
    print_header("M3: CI Pipeline & Testing")
    
    results['tests'] = check_file_exists(
        "tests/test_preprocessing.py",
        "Preprocessing tests"
    ) and check_file_exists(
        "tests/test_inference.py",
        "Inference tests"
    )
    
    results['pytest'] = run_command(
        "python -m pytest --version",
        "Pytest installed",
        check=False
    )
    
    results['ci'] = check_file_exists(
        ".github/workflows/ci.yml",
        "CI pipeline configuration"
    )
    
    # M4: Deployment
    print_header("M4: CD Pipeline & Deployment")
    
    results['k8s_deployment'] = check_file_exists(
        "deployment/kubernetes/deployment.yaml",
        "Kubernetes deployment manifest"
    )
    
    results['k8s_service'] = check_file_exists(
        "deployment/kubernetes/service.yaml",
        "Kubernetes service manifest"
    )
    
    results['cd'] = check_file_exists(
        ".github/workflows/cd.yml",
        "CD pipeline configuration"
    )
    
    results['smoke_tests'] = check_file_exists(
        "scripts/smoke_test.sh",
        "Smoke test script"
    )
    
    # M5: Monitoring
    print_header("M5: Monitoring & Logging")
    
    # Check if monitoring code is in API
    results['monitoring'] = run_command(
        "grep -q 'prometheus_client' api/main.py",
        "Prometheus monitoring in API",
        check=False
    )
    
    results['logging'] = run_command(
        "grep -q 'logging' api/main.py",
        "Logging configured in API",
        check=False
    )
    
    results['eval_script'] = check_file_exists(
        "scripts/evaluate_performance.py",
        "Performance evaluation script"
    )
    
    # Summary
    print_header("Verification Summary")
    
    total = len(results)
    passed = sum(1 for v in results.values() if v)
    failed = total - passed
    
    print(f"Total checks: {total}")
    print(f"Passed: {passed} ✓")
    print(f"Failed: {failed} ✗")
    print(f"\nSuccess rate: {(passed/total)*100:.1f}%")
    
    if failed > 0:
        print("\nFailed checks:")
        for name, status in results.items():
            if not status:
                print(f"  ✗ {name}")
    
    print("\n" + "=" * 60)
    
    if failed == 0:
        print("✓ All verification checks passed!")
        print("\nNext steps:")
        print("1. Run './scripts/setup.sh' to setup environment")
        print("2. Run 'python src/model.py' to train model")
        print("3. Run 'pytest tests/ -v' to run tests")
        print("4. Run './scripts/run_docker.sh' to start API")
        return 0
    else:
        print("✗ Some verification checks failed")
        print("\nPlease review the failed checks above")
        return 1


if __name__ == "__main__":
    sys.exit(main())

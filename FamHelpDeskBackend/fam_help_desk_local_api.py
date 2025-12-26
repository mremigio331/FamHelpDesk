#!/usr/bin/env python3
"""
Run FamHelpDesk API locally with HTTPS support.
Generates self-signed SSL certificates if needed and starts uvicorn server.
"""

from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from datetime import datetime, timedelta, timezone
import ipaddress
import os
import subprocess
import sys


def generate_self_signed_cert(cert_dir="certs", days_valid=365):
    """
    Generate a self-signed certificate for localhost development.
    
    Args:
        cert_dir: Directory to store the certificate files
        days_valid: Number of days the certificate should be valid
    """
    # Create certs directory if it doesn't exist
    os.makedirs(cert_dir, exist_ok=True)
    
    cert_path = os.path.join(cert_dir, "cert.pem")
    key_path = os.path.join(cert_dir, "key.pem")
    
    # Check if certificates already exist
    if os.path.exists(cert_path) and os.path.exists(key_path):
        print(f"Certificates already exist in {cert_dir}/")
        print(f"  - {cert_path}")
        print(f"  - {key_path}")
        return cert_path, key_path
    
    print("Generating self-signed SSL certificate...")
    
    # Generate private key
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    
    # Generate certificate
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
        x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, "Local"),
        x509.NameAttribute(NameOID.LOCALITY_NAME, "Local"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "FamHelpDesk Dev"),
        x509.NameAttribute(NameOID.COMMON_NAME, "localhost"),
    ])
    
    cert = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        issuer
    ).public_key(
        private_key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).not_valid_before(
        datetime.now(timezone.utc)
    ).not_valid_after(
        datetime.now(timezone.utc) + timedelta(days=days_valid)
    ).add_extension(
        x509.SubjectAlternativeName([
            x509.DNSName("localhost"),
            x509.DNSName("127.0.0.1"),
            x509.IPAddress(ipaddress.IPv4Address("127.0.0.1")),
        ]),
        critical=False,
    ).sign(private_key, hashes.SHA256())
    
    # Write private key to file
    with open(key_path, "wb") as f:
        f.write(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption()
        ))
    
    # Write certificate to file
    with open(cert_path, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))
    
    print(f"✓ SSL certificates generated successfully!")
    print(f"  - Certificate: {cert_path}")
    print(f"  - Private Key: {key_path}")
    print(f"  - Valid for {days_valid} days")
    print("\nNote: These are self-signed certificates for development only.")
    print("Your browser will show a security warning - this is expected.\n")
    
    return cert_path, key_path


def run_uvicorn():
    """Run uvicorn server with SSL certificates."""
    # Generate certificates if needed
    cert_path, key_path = generate_self_signed_cert()
    
    # Run uvicorn with HTTPS
    cmd = [
        "uvicorn",
        "app:app",
        "--reload",
        "--port", "5000",
        "--ssl-keyfile", key_path,
        "--ssl-certfile", cert_path
    ]
    
    print(f"Starting uvicorn server with HTTPS on port 5000...")
    print(f"URL: https://localhost:5000\n")
    
    try:
        subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\nShutting down server...")
        sys.exit(0)


if __name__ == "__main__":
    run_uvicorn()

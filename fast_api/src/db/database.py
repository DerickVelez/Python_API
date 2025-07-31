from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = ("postgresql://postgres_admin:DemoAppSecurePass1!@demo-postgres-db.cwlki4gus6vp.us-east-1.rds.amazonaws.com:5432/demoappdb")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()

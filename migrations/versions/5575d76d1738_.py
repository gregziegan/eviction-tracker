"""empty message

Revision ID: 5575d76d1738
Revises: 243c813807f4
Create Date: 2021-04-04 09:21:23.716567

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '5575d76d1738'
down_revision = '243c813807f4'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.alter_column('defendants', 'first_name',
               existing_type=sa.VARCHAR(length=50),
               type_=sa.String(length=255),
               existing_nullable=True)
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.alter_column('defendants', 'first_name',
               existing_type=sa.String(length=255),
               type_=sa.VARCHAR(length=50),
               existing_nullable=True)
    # ### end Alembic commands ###

"""empty message

Revision ID: 74fdabe3d5a3
Revises: c9c893e7d8e0
Create Date: 2021-07-25 09:25:04.354757

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '74fdabe3d5a3'
down_revision = 'c9c893e7d8e0'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.alter_column('detainer_warrants', 'file_date',
               existing_type=sa.DATE(),
               nullable=True)
    op.alter_column('detainer_warrants', 'status_id',
               existing_type=sa.INTEGER(),
               nullable=True)
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.alter_column('detainer_warrants', 'status_id',
               existing_type=sa.INTEGER(),
               nullable=False)
    op.alter_column('detainer_warrants', 'file_date',
               existing_type=sa.DATE(),
               nullable=False)
    # ### end Alembic commands ###

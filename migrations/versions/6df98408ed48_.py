"""empty message

Revision ID: 6df98408ed48
Revises: f019e4f1d25c
Create Date: 2021-07-31 12:06:29.230566

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '6df98408ed48'
down_revision = 'f019e4f1d25c'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('judgements', 'defendant_address')
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.add_column('judgements', sa.Column('defendant_address', sa.VARCHAR(length=255), autoincrement=False, nullable=True))
    # ### end Alembic commands ###

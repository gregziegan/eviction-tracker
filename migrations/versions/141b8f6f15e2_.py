"""empty message

Revision ID: 141b8f6f15e2
Revises: bfe5032cbec7
Create Date: 2022-01-14 14:14:38.683904

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '141b8f6f15e2'
down_revision = 'bfe5032cbec7'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.add_column('cases', sa.Column('document_url', sa.String(), nullable=True))
    op.create_foreign_key(None, 'cases', 'pleading_documents', ['document_url'], ['url'])
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_constraint(None, 'cases', type_='foreignkey')
    op.drop_column('cases', 'document_url')
    # ### end Alembic commands ###

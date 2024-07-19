"""empty message

Revision ID: 86b7c9141a09
Revises: 4df3919e6542
Create Date: 2024-07-18 21:51:04.245014

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '86b7c9141a09'
down_revision = '4df3919e6542'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    with op.batch_alter_table('cases', schema=None) as batch_op:
        batch_op.create_foreign_key('cases_document_image_path_fkey', 'pleading_documents', ['document_image_path'], ['image_path'], use_alter=True)

    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    with op.batch_alter_table('cases', schema=None) as batch_op:
        batch_op.drop_constraint('cases_document_image_path_fkey', type_='foreignkey')

    # ### end Alembic commands ###

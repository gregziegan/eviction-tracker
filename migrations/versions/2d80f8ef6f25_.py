"""empty message

Revision ID: 2d80f8ef6f25
Revises: 29fb789ae54f
Create Date: 2021-04-21 21:05:46.788425

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '2d80f8ef6f25'
down_revision = '29fb789ae54f'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.execute(
        'UPDATE detainer_warrants SET amount_claimed_category_id = 3 WHERE amount_claimed_category_id IS NULL'
    )
    op.alter_column('detainer_warrants', 'amount_claimed_category_id',
                    existing_type=sa.INTEGER(),
                    nullable=False)
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.alter_column('detainer_warrants', 'amount_claimed_category_id',
                    existing_type=sa.INTEGER(),
                    nullable=True)
    # ### end Alembic commands ###

"""empty message

Revision ID: 49a360ed287b
Revises: 611584f72ec8
Create Date: 2021-10-17 10:32:16.619529

"""
from alembic import op
import sqlalchemy as sa
from rdc_website.detainer_warrants.models import DetainerWarrant
from sqlalchemy.orm.session import Session

# revision identifiers, used by Alembic.
revision = '49a360ed287b'
down_revision = '611584f72ec8'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    session = Session(bind=op.get_bind())

    op.add_column('detainer_warrants', sa.Column(
        'order_number', sa.BigInteger()))
    for warrant in session.query(DetainerWarrant):
        try:
            warrant.order_number = int(warrant.docket_id.replace(
                'GT', '').replace('GC', '0').replace('.CC', '123123'))
        except ValueError:
            warrant.order_number = 0
        session.add(warrant)

    session.commit()

    op.alter_column('detainer_warrants', 'order_number',
                    existing_type=sa.BIGINT(),
                    nullable=False)
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('detainer_warrants', 'order_number')
    # ### end Alembic commands ###

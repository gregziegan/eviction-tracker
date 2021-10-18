"""empty message

Revision ID: bef0228518e5
Revises: 49a360ed287b
Create Date: 2021-10-17 18:48:48.540145

"""
from alembic import op
import sqlalchemy as sa
from eviction_tracker.admin.models import User
from sqlalchemy.orm.session import Session


# revision identifiers, used by Alembic.
revision = 'bef0228518e5'
down_revision = '49a360ed287b'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    session = Session(bind=op.get_bind())

    op.add_column('user', sa.Column('preferred_navigation_id', sa.Integer()))

    for user in session.query(User):
        user.preferred_navigation = 'REMAIN'
        session.add(user)

    session.commit()

    op.alter_column('user', 'preferred_navigation_id',
                    existing_type=sa.INTEGER(),
                    nullable=False)
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('user', 'preferred_navigation_id')
    # ### end Alembic commands ###

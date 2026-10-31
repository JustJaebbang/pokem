from schemas.public_profile import PublicProfileResponse

def get_public_profile(db,user_id):
    with db.cursor() as cursor:
        cursor.execute("""
            SELECT u.user_id,u.user_nickname,u.user_profile_image,
              EXISTS(SELECT 1 FROM `quit` q WHERE q.user_user_id=u.user_id) AS is_withdrawn
            FROM `user` u WHERE u.user_id=%s
        """,(user_id,))
        row=cursor.fetchone()
    if row is None: return None
    if row['is_withdrawn']:
        row['user_nickname']='탈퇴한 사용자'
        row['user_profile_image']=None
    return PublicProfileResponse(**row)

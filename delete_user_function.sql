-- Function to allow users to delete their own account
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void AS $$
BEGIN
    -- 1. Delete the user's cases (reports)
    -- This is necessary because cases has ON DELETE SET NULL which keeps PII
    DELETE FROM public.cases WHERE reporter_id = auth.uid();

    -- 2. Delete the user's moderation history if any (moderators can also delete accounts)
    -- Assuming there might be a moderation_history table
    DELETE FROM public.moderation_history WHERE moderator_id = auth.uid();

    -- 3. Delete the user from auth.users
    -- This will trigger CASCADE deletes on profiles, notifications, etc.
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Revoke execute from public to be safe, then grant back to authenticated users
REVOKE EXECUTE ON FUNCTION delete_user_account() FROM public;
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;

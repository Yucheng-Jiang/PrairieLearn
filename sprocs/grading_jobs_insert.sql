DROP FUNCTION IF EXISTS grading_jobs_insert(bigint,bigint,boolean,jsonb,jsonb,double precision,jsonb,jsonb,jsonb,jsonb);

DROP FUNCTION IF EXISTS grading_jobs_insert(bigint,bigint,boolean,boolean,jsonb,jsonb,double precision,jsonb,jsonb,jsonb,jsonb);

CREATE OR REPLACE FUNCTION
    grading_jobs_insert (
        IN submission_id bigint,
        IN authn_user_id bigint,
        IN new_gradable boolean DEFAULT NULL,
        IN new_broken boolean DEFAULT NULL,
        IN new_format_errors jsonb DEFAULT NULL,
        IN new_partial_scores jsonb DEFAULT NULL,
        IN new_score double precision DEFAULT NULL,
        IN new_v2_score double precision DEFAULT NULL,
        IN new_feedback jsonb DEFAULT NULL,
        IN new_submitted_answer jsonb DEFAULT NULL,
        IN new_params jsonb DEFAULT NULL,
        IN new_true_answer jsonb DEFAULT NULL,
        OUT grading_jobs grading_jobs[]
    )
AS $$
DECLARE
    grading_method_internal boolean;
    grading_method_external boolean;
    grading_method_manual boolean;
BEGIN
    PERFORM submissions_lock(submission_id);

    -- ######################################################################
    -- get the grading method

    SELECT q.grading_method_internal, q.grading_method_external, q.grading_method_manual
    INTO     grading_method_internal,   grading_method_external,   grading_method_manual
    FROM
        submissions AS s
        JOIN variants AS v ON (v.id = s.variant_id)
        JOIN questions AS q ON (q.id = v.question_id)
    WHERE s.id = submission_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'no such submission_id: %', submission_id; END IF;

    -- ######################################################################
    -- build up all grading jobs
    IF grading_method_internal = False AND grading_method_external = False AND grading_method_manual = False THEN
        RAISE EXCEPTION 'all grading methods set to false: (internal %s, external %s, manual %s)', grading_method_internal, grading_method_external, grading_method_manual;
    END IF;
    
    grading_jobs = []
    
    -- delegate internal grading job ()
    IF grading_method_internal = True THEN
        grading_jobs = grading_jobs || grading_jobs_insert_internal(submission_id, authn_user_id,
                            new_gradable, new_broken, new_format_errors, new_partial_scores,
                            new_score, new_v2_score, new_feedback, new_submitted_answer,
                            new_params, new_true_answer);
    
    -- delegate external/manual grading job
    IF grading_method_external = True OR grading_method_manual = True THEN
        grading_job_external = grading_jobs || grading_jobs_insert_external_manual(submission_id, authn_user_id, 'External');

    IF grading_method_manual = TRUE THEN
        grading_job = grading_jobs || grading_jobs_insert_external_manual(submission_id, authn_user_id, 'Manual');
END;
$$ LANGUAGE plpgsql VOLATILE;

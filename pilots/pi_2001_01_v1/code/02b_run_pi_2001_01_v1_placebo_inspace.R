source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
extra_packages <- c("tidyr", "quadprog")
missing_extra  <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id      <- "pi_2001_01_v1"
treated_state <- "PI"
min_pre_periods <- 20L
pilot_root    <- file.path(root_dir, "pilots", pilot_id)
data_dir      <- file.path(pilot_root, "data")
output_root   <- file.path(pilot_root, "output")
placebo_dir   <- file.path(output_root, "placebo_inspace")
table_dir     <- file.path(pilot_root, "report", "tables")
dir.create(placebo_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir,   recursive = TRUE, showWarnings = FALSE)

covariates_raw <- readr::read_csv(file.path(data_dir, "pi_2001_01_v1_covariates.csv"),          show_col_types = FALSE)
monthly_panel  <- readr::read_csv(file.path(data_dir, "pi_2001_01_v1_monthly_panel.csv"),       show_col_types = FALSE) |> dplyr::mutate(period_date = as.Date(.data$period_date))
fiscal_panel   <- monthly_panel  # V1: single monthly panel
scm_summary    <- readr::read_csv(file.path(output_root, "pi_2001_01_v1_scm_summary.csv"),       show_col_types = FALSE)

main_donor_states <- covariates_raw |> dplyr::filter(.data$donor_pool_main) |> dplyr::pull(.data$state_abbrev) |> sort()
covariates        <- covariates_raw |> dplyr::select(-dplyr::any_of(c("donor_pool_main","excluded_from_main_donor_pool","donor_pool_exclusion_reason","monthly_pre_periods")))

make_slug <- function(x) { x |> stringr::str_replace_all("[^A-Za-z0-9]+","_") |> stringr::str_replace_all("_+$","") |> tolower() }

# ── Shared SCM primitives ─────────────────────────────────────────────────────
standardize_by_row <- function(x) {
  rm <- rowMeans(x, na.rm=TRUE); rs <- apply(x,1,stats::sd,na.rm=TRUE); keep <- is.finite(rs)&rs>0
  xs <- sweep(x[keep,,drop=FALSE],1,rm[keep],"-"); xs <- sweep(xs,1,rs[keep],"/")
  list(x=xs, keep=keep)
}
standardize_units <- function(x_tr,x_all) {
  cm <- colMeans(x_tr,na.rm=TRUE); cs <- apply(x_tr,2,stats::sd,na.rm=TRUE)
  cs[!is.finite(cs)|cs==0] <- 1
  list(x_all=sweep(sweep(x_all,2,cm,"-"),2,cs,"/"))
}
solve_weights <- function(x1,x0) {
  dmat <- 2*crossprod(x0)+diag(1e-8,ncol(x0)); dvec <- 2*as.numeric(crossprod(x0,x1))
  amat <- cbind(rep(1,ncol(x0)),diag(ncol(x0))); bvec <- c(1,rep(0,ncol(x0)))
  sol  <- quadprog::solve.QP(dmat,dvec,amat,bvec,meq=1); w <- pmax(sol$solution,0); w/sum(w)
}
fit_ridge <- function(x,y,lam) { d<-cbind(1,x); p<-diag(ncol(d)); p[1,1]<-0; as.numeric(solve(crossprod(d)+lam*p,crossprod(d,y))) }
predict_ridge <- function(x,co) as.numeric(cbind(1,x)%*%co)
loocv_lambda <- function(x,y,lams) {
  if(nrow(x)<5) return(1)
  cv <- vapply(lams,function(lam){errs<-vapply(seq_along(y),function(i){co<-fit_ridge(x[-i,,drop=FALSE],y[-i],lam);y[i]-predict_ridge(x[i,,drop=FALSE],co)},numeric(1));sqrt(mean(errs^2,na.rm=TRUE))},numeric(1))
  lams[which.min(cv)]
}
lambda_grid <- 10^seq(-4,5,length.out=20)

fit_ascm_for_unit <- function(data, outcome, pseudo_treated, donor_pool, covariate_data) {
  all_st <- c(pseudo_treated, donor_pool)
  pre    <- data |> dplyr::filter(.data$analysis_period=="pre",.data$state_abbrev %in% all_st) |>
    dplyr::select(.data$state_abbrev,.data$period_date,value=dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from=.data$state_abbrev,values_from=.data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_st))))
  if(nrow(pre)<min_pre_periods) return(NULL)

  om <- pre |> dplyr::select(dplyr::all_of(all_st)) |> as.matrix()
  rownames(om) <- paste0("pre_",format(pre$period_date,"%Y_%m_%d"))

  cl <- covariate_data |> dplyr::filter(.data$state_abbrev %in% all_st) |>
    tidyr::pivot_longer(-.data$state_abbrev,names_to="p",values_to="v") |>
    tidyr::pivot_wider(names_from=.data$state_abbrev,values_from=.data$v) |> dplyr::arrange(.data$p)
  cm <- cl |> dplyr::select(dplyr::all_of(all_st)) |> as.matrix()
  rownames(cm) <- paste0("cov_",cl$p)

  pm <- rbind(om,cm)
  if(anyNA(pm)) return(NULL)

  sc   <- standardize_by_row(pm); x1 <- sc$x[,pseudo_treated,drop=FALSE]; x0 <- sc$x[,donor_pool,drop=FALSE]
  w    <- solve_weights(x1,x0); names(w) <- donor_pool
  up   <- t(pm); dp <- up[donor_pool,,drop=FALSE]; ap <- up[all_st,,drop=FALSE]
  su   <- standardize_units(dp,ap); tp <- su$x_all[pseudo_treated,,drop=FALSE]; dps <- su$x_all[donor_pool,,drop=FALSE]
  imb  <- tp - matrix(as.numeric(t(w)%*%dps),nrow=1)

  wide <- data |> dplyr::filter(.data$state_abbrev %in% all_st) |>
    dplyr::select(.data$period_date,.data$analysis_period,.data$state_abbrev,value=dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from=.data$state_abbrev,values_from=.data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_st))))

  corrections <- purrr::map_dfr(seq_len(nrow(wide)), function(i) {
    yd<-as.numeric(wide[i,donor_pool,drop=TRUE]); yc<-mean(yd,na.rm=TRUE); ys<-stats::sd(yd,na.rm=TRUE)
    if(!is.finite(ys)||ys==0) ys<-1; yds<-(yd-yc)/ys
    lam<-loocv_lambda(dps,yds,lambda_grid); co<-fit_ridge(dps,yds,lam)
    tibble::tibble(period_date=wide$period_date[i], augmentation_correction=as.numeric(imb%*%co[-1])*ys)
  })

  synth <- as.matrix(wide[,donor_pool,drop=FALSE])%*%w
  path  <- wide |>
    dplyr::transmute(.data$period_date,.data$analysis_period,treated_value=.data[[pseudo_treated]],scm_synthetic=as.numeric(synth)) |>
    dplyr::left_join(corrections,by="period_date") |>
    dplyr::mutate(augmented_synthetic=.data$scm_synthetic+.data$augmentation_correction,
                  augmented_gap=.data$treated_value-.data$augmented_synthetic)

  rmspe_pre  <- sqrt(mean(path$augmented_gap[path$analysis_period=="pre"]^2,  na.rm=TRUE))
  rmspe_post <- sqrt(mean(path$augmented_gap[path$analysis_period=="post"]^2, na.rm=TRUE))
  mean_abs   <- mean(abs(path$augmented_gap[path$analysis_period=="post"]),   na.rm=TRUE)

  list(path=path, rmspe=tibble::tibble(pre_rmspe=rmspe_pre,post_rmspe=rmspe_post,
       mean_abs_gap_post=mean_abs,post_pre_ratio=rmspe_post/rmspe_pre))
}

# ── Preferred specs ────────────────────────────────────────────────────────────
preferred_specs <- tibble::tribble(
  ~outcome,                                   ~family,    ~specification, ~channel_slug,   ~short_label,
  "va_icms_total_real_pc_sa",                "monthly",  "sa",           "tax_base",      "ICMS total VA",
  "va_receita_tributaria_total_real_pc_sa",  "monthly",  "sa",           "tax_base",      "Tax revenue VA",
  "va_icms_terciario_varejista_real_pc_sa",  "monthly",  "sa",           "tax_base",      "ICMS retail VA",
  "retail_volume_index_sa",                  "monthly",  "sa",           "consumption",   "Retail volume"
)

get_panel <- function(family) if(family=="monthly") monthly_panel else fiscal_panel

# ── Run placebos ───────────────────────────────────────────────────────────────
message("Running in-space placebo: ", length(main_donor_states), " states x ", nrow(preferred_specs), " outcomes")
all_paths <- list(); all_rmspe <- list(); n_done <- 0L

for (ps in main_donor_states) {
  donor_pool <- setdiff(main_donor_states, ps)
  for (i in seq_len(nrow(preferred_specs))) {
    spec  <- preferred_specs[i,]
    panel <- get_panel(spec$family)
    res   <- tryCatch(fit_ascm_for_unit(panel, spec$outcome, ps, donor_pool, covariates), error=function(e) NULL)
    if (!is.null(res)) {
      all_paths[[length(all_paths)+1L]] <- res$path |>
        dplyr::transmute(pseudo_treated_state=ps, outcome=spec$outcome, short_label=spec$short_label,
                         channel_slug=spec$channel_slug, .data$period_date, .data$analysis_period, .data$augmented_gap)
      all_rmspe[[length(all_rmspe)+1L]] <- res$rmspe |>
        dplyr::mutate(pseudo_treated_state=ps, outcome=spec$outcome, short_label=spec$short_label, channel_slug=spec$channel_slug)
      n_done <- n_done+1L
    }
  }
  message("  Done: ", ps, " (", n_done, " models)")
}

placebo_paths   <- dplyr::bind_rows(all_paths)
placebo_summary <- dplyr::bind_rows(all_rmspe)
readr::write_csv(placebo_paths,   file.path(placebo_dir, "placebo_paths_preferred_smooth.csv"),   na="")
readr::write_csv(placebo_summary, file.path(placebo_dir, "placebo_summary_preferred_smooth.csv"), na="")

# ── RMSPE p-values ──────────────────────────────────────────────────────────────
rr_rmspe <- scm_summary |>
  dplyr::filter(.data$status=="estimated", .data$specification=="sa",
                .data$outcome %in% preferred_specs$outcome) |>
  dplyr::left_join(preferred_specs |> dplyr::select("outcome","short_label","channel_slug"), by="outcome") |>
  dplyr::transmute(outcome, short_label, channel_slug,
                   rr_ratio   = .data$augmented_rmspe_post / .data$augmented_rmspe_pre,
                   rr_abs_gap = abs(.data$augmented_mean_gap_post))

placebo_rank <- purrr::map_dfr(seq_len(nrow(rr_rmspe)), function(i) {
  row    <- rr_rmspe[i,]
  p_rows <- placebo_summary |> dplyr::filter(.data$outcome==row$outcome)
  n      <- nrow(p_rows)
  tibble::tibble(
    outcome=row$outcome, short_label=row$short_label, channel_slug=row$channel_slug,
    post_pre_rmspe_ratio=row$rr_ratio, donor_placebo_count=n,
    ratio_p_value   = if(n>0) mean(p_rows$post_pre_ratio>=row$rr_ratio,na.rm=TRUE) else NA_real_,
    abs_gap_p_value = if(n>0) mean(p_rows$mean_abs_gap_post>=row$rr_abs_gap,na.rm=TRUE) else NA_real_
  )
})

readr::write_csv(placebo_rank, file.path(table_dir, "placebo_rank_actual_rr.csv"), na="")
message("In-space placebo completed. Models: ", n_done)

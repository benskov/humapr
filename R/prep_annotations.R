prep_annotations <- function(mapped_loc, symmetric_map = TRUE) {
    if (!h_env$annotate %in% c("all", "freq"))
        return() # do nothing

    combine <- h_env$combine
    proj <- h_env$proj
    body_halves <- h_env$body_halves
    map_name <- h_env$map_name

    # Applying defaults
    h_env$controls$label_pad <- diff(range(h_env$mapdf$lat)) * (h_env$controls$label_pad %||% 3.5) / 100
    # Compute coords on the spot, if not pre-computed (they really should be, and will be down the road)
    if (is.null(h_env$coords)) {
        coords <- h_env$mapdf %>%
            dplyr::mutate(plot_mid = mean(range(long))) %>% # is useful to mirror and inverse coordinates later
            dplyr::group_by(id) %>%
            dplyr::summarise(x0 = mean(range(long)),
                             y0 = mean(range(lat)),
                             plot_mid = plot_mid[1],
                             label_side = ifelse(x0 > plot_mid, "right", "left")) %>%
            dplyr::group_by(label_side) %>%
            dplyr::mutate(side_mid = mean(range(x0))) %>%
            dplyr::rename(region = id) %>%
            as.data.frame()
    } else {
        coords <- h_env$coords
    }

    # In the end, which regions are actually mapped?
    mapped_regions <- if (body_halves == "join" | h_env$map_name %in% c("internal_organs")) {
        mapped_loc
    } else {
        rm_lr(mapped_loc)
    }
    mapped_regions <- as.vector(na.exclude(unique(mapped_regions)))

    if (!is.null(combine)) {
        # Consider checking that combine input has appropriate form (particularly, combinations' names)
        for (combine_name in names(combine))
            mapped_regions[mapped_regions == combine_name] <- combine[[combine_name]][[1]]
        if (map_name %in% c("internal_organs")) {
            coords <- dplyr::filter(coords, region %in% mapped_regions)
        } else {
            coords <- dplyr::filter(coords, region %in% lr_conc(mapped_regions))
        }
    }

    # Tweak x0 values, if necessary, so we can use the same distribution algorithm
    if (h_env$map_name == 'internal_organs') {
        # Not very elegant/modular, but will work just fine for now
        coords <- dplyr::filter(coords, region %in% mapped_regions) %>%
            inverse_coords("x0", .$plot_mid[1])
    } else {
        if (body_halves == "join") {
            coords <- dplyr::filter(coords, region %in% paste0("right_", mapped_regions))
            if (isTRUE(symmetric_map))
                coords <- dplyr::arrange(coords, desc(y0)) %>%
                    dplyr::mutate(label_side = ifelse(seq(region) %% 2 == 1, "left", "right"))
        } else {
            coords <- dplyr::filter(coords, region %in% lr_conc(mapped_regions)) %>%
                inverse_coords("x0")
        }
    }

    # Distribute line break points vertically, on each side
    coords <- rbind(def_dist(coords[coords$label_side == "left", ]),
                    def_dist(coords[coords$label_side == "right", ]))

    # Fix and tweak coordinates to be appropriate for the chosen map
    if (map_name %in% c("internal_organs")) {
        coords <- inverse_coords(coords, c("x0", "x1"), coords$plot_mid[1]) # Inverse back, to get correct location of points
    } else {
        if (body_halves == "separate")
            coords <- inverse_coords(coords, c("x0", "x1")) # Inverse back, to get correct location of points

        if (body_halves == "join" & isTRUE(symmetric_map))
            coords <- dplyr::mutate(coords,
                                    x0 = mirror_coord(x0, plot_mid, label_side, "right"), # mirror around mid of plot
                                    x1 = mirror_coord(x1, plot_mid, label_side, "right")) # idem

        if (body_halves == "join" & isFALSE(symmetric_map))
            coords <- dplyr::mutate(coords,
                                    x0 = mirror_coord(x0, side_mid, label_side, "right"), # mirror around mid of sub-plot
                                    x1 = mirror_coord(x1, side_mid, label_side, "right")) # idem
    }

    h_env$anno_coords <- coords
}
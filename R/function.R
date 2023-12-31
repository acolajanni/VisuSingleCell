################################################################################
# > September 2023
# > Script : function.R
# > Function : reserve of function to load and visualize single cells
# > tabula sapiens matrix results
# @ COLAJANNI Antonin
################################################################################


#' Create a directory
#'
#' If the direcotry exists, returns the path to directory
#'
#' @param directory str
#'
#' @return
#' @export
create_dir = function(directory){
  if ( ! file.exists(directory)){
    dir.create(directory)  }
  return(directory) }


#' computes confidence interval
#'
#'
#' @param perm_df dataframe
#' @param n_perm int
#'
#' @return
#' @export
#'
#' @examples
confidence_interval = function(perm_df, n_perm = 20) {
  t.score=qt(p=0.025, df=n_perm-1 ,lower.tail = FALSE)
  perm_df$se = perm_df$std_importance/sqrt(n_perm-1)
  perm_df$margin_error = t.score*perm_df$se
  perm_df$binf = perm_df$mean_importance - perm_df$margin_error
  perm_df$bsup = perm_df$mean_importance + perm_df$margin_error

  return(perm_df) }


#' Build the importance barlot
#'
#' @param permutation_df dataframe
#' @param permutation_number int
#' @param filter type of filtration: among c(bsup,binf,zero,mean)
#' bsup : greater threshold of the mean confidence interval
#' binf : lower threshold of the mean confidence interval
#' zero : remove mean importance value if imp = 0 or inferior
#' mean : keeps genes with importance above mean
#' @param title str, title of plot
#' @param conf_interval Boolean
#'
#' @return
#' @import ggplot2
#' @export
#'
#' @examples
importance_barplot = function(permutation_df,permutation_number=50, filter="mean", title="Mean feature importance barplot",
                              conf_interval = TRUE){
  if (conf_interval){
    permutation_df = confidence_interval(permutation_df, permutation_number)
  }
  else {
    permutation_df$binf = permutation_df$mean_importance
    permutation_df$bsup = permutation_df$mean_importance
  }
  non_null_feature = length(permutation_df[permutation_df$mean_importance != 0 , ]$mean_importance)
  pos_feature = length(permutation_df[permutation_df$mean_importance > 0 , ]$mean_importance)


  if (filter == "mean") {
    permutation_df = permutation_df[permutation_df$mean_importance > 0 , ]
    subtitle = paste(non_null_feature, "Genes with non null feature importance among which", pos_feature, "have a positive importance") }
  else {
    sig_pos_feature = length(permutation_df[permutation_df$binf > 0 , ]$mean_importance)
    subtitle = paste(non_null_feature, "Genes with non null feature importance among which", pos_feature, "have a positive importance and \n ",
                     sig_pos_feature, "are significantly different than zero.")

    if (filter == "bsup") { permutation_df = permutation_df[permutation_df$bsup > 0 , ] }
    else if (filter == "binf") { permutation_df = permutation_df[permutation_df$binf > 0 , ] }
    else if (filter == "zero") { permutation_df = permutation_df[permutation_df$mean_importance != 0 , ] }
  }


  permutation_df$genes = row.names(permutation_df)
  n_gene = length(row.names(permutation_df))
  ordered_permutation_df = permutation_df[order(permutation_df$mean_importance, decreasing = TRUE),]

  plot = ggplot( permutation_df, aes(x = reorder(genes,mean_importance), y = mean_importance, fill=mean_importance ) )  +
    geom_col(position = position_dodge(0), width = 0.75) +
    geom_errorbar(aes(ymin=binf, ymax=bsup ),
                  size=.3,width=.2, position=position_dodge(.9)) +
    geom_hline(aes(yintercept = 0), alpha=0.20) +
    coord_flip() +
    labs(fill = "Cluster") +
    ylab('Mean Permutation Feature Importance') + xlab('Gene name')+
    ggtitle(title, subtitle = subtitle ) +

    scale_fill_viridis(discrete = FALSE, alpha=0.65, direction = -1, option='C', name="Mean Feature Importance") +
    theme_linedraw()+
    theme( plot.title = element_text(size=15),
           axis.text.y = element_text(size = 8))
  return(list("plot"=plot,
              "ordered_permutation_dataframe" = ordered_permutation_df[,-c(1:permutation_number)],
              "permutation_dataframe"= permutation_df)) }


#' Add a line bellow a gene from the function "importance_barplot"
#'
#' @param plot ggplot object
#' @param permutation_df dataframe
#' @param last_gene str, name of gene bellow which to place the line
#' @param annotation str, to be displayed near the line
#' @param adjust_annotation float
#' @param adjust_annotationX float
#'
#' @return
#' @import ggplot2
#' @export
#'
#' @examples
add_annotation_line_barplot_importance = function(plot, permutation_df, last_gene, annotation = "most important features", adjust_annotation = .25, adjust_annotationX=0.85){
  gene_value = permutation_df[permutation_df$genes == last_gene,]$mean_importance
  gene_rank = length(permutation_df[permutation_df$mean_importance >= gene_value,]$genes)

  plot = plot +
    geom_vline( xintercept = which(permutation_df$genes == last_gene)-0.5, linetype='dashed' )+
    annotate("text", x=which(permutation_df$genes == last_gene)+adjust_annotation , y=max(permutation_df$mean_importance)*adjust_annotationX,
             label= paste(gene_rank,annotation) )
  return(plot) }



#' Ratio - Average Plot
#'
#' @param FC_df dataframe
#' @param x str, name of the column to be displayed in x
#' @param y str, name of the column to be displayed in x
#' @param title str,
#' @param highlight str, type of highlighting: 'TOP20' to highlight the top20 genes with highest FC or a specific gene to precise
#' @param annotation str to be displayed on graĥ
#' @param vjust int
#' @param force int
#' @param y_scale int
#' @param add_label Boolean
#'
#' @return
#' @import ggplot2
#' @import ggrepel
#' @export
#'
#' @examples
RA_plot = function(FC_df, x, y, title = "RA plot", highlight=c('TOP20'), annotation = "Most Important Features", vjust = 2, force=3, y_scale = 0, add_label=TRUE){

  FC_df$selection = ifelse(FC_df[[x]] > quantile(FC_df[[x]],0.75) & abs(FC_df[[y]]) > 1 ,
                           yes = "Selected",no = "Not selected")
  selected_number= length(FC_df$selection[FC_df$selection == "Selected"])

  if (highlight[1] == "TOP20") {
    FC_df$selection = ifelse(abs(FC_df[[y]]) > sort(abs(FC_df[[y]]),TRUE )[21]  ,
                             yes = "20 Highest FC",no = FC_df$selection)
    FC_df$label = ifelse(FC_df$selection == "20 Highest FC",
                         yes=row.names(FC_df), no="") }
  else{
    FC_df$selection = ifelse(row.names(FC_df) %in% highlight ,
                             yes = annotation, no = FC_df$selection)
    FC_df$label = ifelse(FC_df$selection == annotation,
                         yes=row.names(FC_df), no="") }


  maximum_y = max(abs(FC_df[[y]])) + y_scale
  title =paste( c(title, "\n Gene selected :",selected_number),collapse = " " )

  plot = ggplot(FC_df, aes(x=FC_df[[x]], y=FC_df[[y]]))+
    geom_point(aes(color=selection, alpha=selection, size = selection))+
    geom_smooth(color="darkred",size=0.5)+
    annotate("text", x=2.4, y=-1-0.5, label="log2 FC = -1", colour = "darkblue") +
    geom_hline(yintercept = -1, color='darkblue',linetype='dashed') +
    annotate("text", x=2.4, y= 1+0.5, label="log2 FC = 1", colour = "darkblue") +
    coord_cartesian(ylim=c(-maximum_y,maximum_y))+
    geom_hline(yintercept = 1, color='darkblue',linetype='dashed') +
    geom_vline(xintercept = quantile(FC_df[[x]],0.75),linetype='dashed') +
    annotate("text", y=-5.5, x= quantile(FC_df[[x]],0.75)/4,
             label="3rd quartile \n of mean expression", colour = "black") +

    scale_color_manual(values = c("orangered","#777777","#00539CFF"))+
    scale_alpha_manual(values=c(1,0.25, 0.75), guide='none')+
    scale_size_manual(values=c(2,0.5,1), guide='none')+
    theme_linedraw()+
    theme(legend.position = c(0.85, 0.15) ,legend.direction = 'vertical') +
    labs(color="Features", )+
    xlab("Average log expression") +
    ylab("log ratio of expression") +
    ggtitle(title)

  if (add_label){
    plot = plot +
      geom_text_repel(data=FC_df, label = FC_df$label,
                      vjust = vjust, force=force, max.overlaps = 100) }

  return(list("plot"=plot, "df"=FC_df)) }


#' Query GO annotation for a set of gene and returns a visualisation
#'
#' @param Annotation_table dataframe
#' @param celltype str, in ttitle of the graph
#'
#' @return
#' @import ggplot2
#' @export
#'
#' @examples
visualize_annotation = function(Annotation_table, celltype){
  Freq_annot = as.data.frame(table(Annotation_table$goslim_goa_description))

  plot = ggplot(Freq_annot, aes(x = reorder(Var1,Freq), y = Freq, fill=Freq)) +
    geom_col() +
    coord_flip() +
    ggtitle(paste("Frequence of annotation terms for", celltype ,"geneset"))+
    xlab('GOSLIM GOA annotation terms') + ylab('Frequence')+ labs(fill="Frequence") +
    theme_linedraw() +
    theme(axis.text = element_text(size=12, face = "bold"))

  df = rmarkdown::paged_table(unique(Annotation_table[,c("hgnc_symbol","entrezgene_description")])  ) %>% datatable

  return(list("df" = df, "plot"=plot)) }

#' takes a list of geneset, returns a dataframe with 0 and 1, genes in row, cell in column
#'
#' @param geneset_list list
#'
#' @return
#' @export
#' @importFrom reshape2 dcast
#' @importFrom plyr ldply
#'
#' @examples
geneset_to_binary_df = function(geneset_list){
  geneset_list_df = lapply(geneset_list, function(x) as.data.frame(x))
  tmp = ldply(geneset_list_df)
  tmp = reshape2::dcast(tmp, x ~ .id)
  row.names(tmp) = tmp$x
  tmp$x = NULL
  tmp = ifelse(is.na(tmp), 0,1)
  return( as.data.frame(tmp) ) }

#' Heatmap for geneset list. red if genes in geneset, darkgrey if not
#'
#' @param geneset_list list
#' @param tabula_column str, name of column from tabula sapiens
#' @param title str
#' @param min_representation int display genes represented a min number of times
#' @param cutree_rows int
#' @param clust Boolean
#'
#' @return
#' @export
#' @import ggplot2
#' @import pheatmap
#'
#' @examples
heatmap_from_geneset_list = function(geneset_list, tabula_column, title = " ",
                                     min_representation = 2, cutree_rows = 1,
                                     clust=TRUE){

  n_cut = length(names(geneset_list))
  all_tabula = geneset_list[[tabula_column]]
  all_signature = unique(unlist(geneset_list[ names(geneset_list) != tabula_column ]))

  unique_tabula = all_tabula[! all_tabula %in% all_signature]
  Full_geneset = unique(unlist(geneset_list))
  geneset_list[["all"]] = Full_geneset
  df_heatmap = fromList(geneset_list)
  row.names(df_heatmap) = geneset_list$all

  main = paste0(title , "\n",
                "Presented genes appears in at least ", min_representation,
                " signature matrix, or in Tabula Sapiens \n",
                length(unique_tabula),
                " Features uniquely predicted in Tabula sapiens geneset " ,
                "\n 1 : Detected by signature matrix",
                "\n 0 : Not detected by signature matrix")

  if (! clust) {return(list("title"=main, "df" = df_heatmap))}

  pheatmap(df_heatmap[
    rowSums(df_heatmap) > min_representation | df_heatmap[[tabula_column]] == 1 ,
    colnames(df_heatmap) != "all"],
    clustering_distance_rows = "correlation", clustering_distance_cols = "correlation",
    cutree_cols = n_cut, cutree_rows = cutree_rows,
    color = c("#555555","red"),
    na_col="lightgray",breaks = c(0, .5 , 1),
    fontsize_row = 14, fontsize_col = 15, angle_col = 0, legend_breaks = c(0,1),
    main = main )
}

#' Plot Fold change with proportion of expression
#'
#' @param df dataframe
#' @param n_cell
#' @param max_cell
#'
#' @return
#' @export
#' @import ggplot2
#'
#' @examples
FC_prop_expr = function(df, n_cell, max_cell){

  columns = colnames(df)[str_detect(colnames(df), "prop_expr")]
  A = columns[!str_detect(columns, "vs")]
  B = columns[ str_detect(columns, paste0("other")) ]

  df[[paste0("FC_",A)]] = compute_FC( df[[A]] , df[[B]] , 0)
  return(df) }

#' Computes threshold with kneedle algorithm
#'
#' @param df dataframe
#' @param y vector
#' @param sens int
#' @param min int
#'
#' @return
#' @export
#' @import kneedle
#' @import ggplot2
#'
#' @examples
kneedle_threshold = function(df, y, sens = 1, min = 0){
  df$value = abs(as.numeric(y))
  df = df[order(df$value, decreasing = TRUE),]
  df$rank = 1:length(y)
  elbow = kneedle(x = df$rank, y = df$value, decreasing = TRUE, concave = FALSE, sensitivity = sens)

  plot = ggplot(df, aes(x=rank,y=value))+
    geom_line()+
    geom_hline(yintercept = elbow[2], color="blue",alpha=0.5) + geom_vline(xintercept = elbow[1], color="blue",alpha=0.5)+
    ylab("y value") + xlab("Gene Rank")

  if (elbow[2] < min) {elbow[2] = min}

  return(list("rank" = elbow[1], "threshold" = elbow[2], "plot"=plot )) }

#' Plot Proportion of expre
#'
#' @param FC_df dataframe
#' @param FC_x Fold change
#' @param y vector
#' @param title str
#' @param highlight str
#' @param annotation str
#' @param vjust int
#' @param force int
#' @param x_scale int
#' @param add_label Boolean
#' @param FC_threshold int
#' @param prop_threshold int
#' @param FC_thresh2 int
#' @param prop_threshold_to_show int
#'
#' @return
#' @export
#' @import ggplot2
#' @import ggrepel
#'
#' @examples
Rprop_plot = function(FC_df, FC_x, y, title = "plot", highlight=c('TOP20'), annotation = "Most Important Features",
                      vjust = 2, force=3, x_scale = 0, add_label=TRUE,
                      FC_threshold = 1, prop_threshold=0.25, FC_thresh2 = 1,
                      prop_threshold_to_show = prop_threshold) {

  FC_df$selection = ifelse(abs(FC_df[[FC_x]]) > FC_threshold & abs(FC_df[[y]]) > prop_threshold ,
                           yes = "Selected",no = "Not selected")
  Display_2nd_annotation = FALSE

  if (FC_threshold <= FC_thresh2){
    FC_df$selection = ifelse(abs(FC_df[[FC_x]]) >= FC_thresh2, yes = "Selected", no = FC_df$selection )
    Display_2nd_annotation = TRUE }

  selected_number= length(FC_df$selection[FC_df$selection == "Selected"])

  if (highlight[1] == "TOP20") {

    tmp_df = FC_df[FC_df[[y]] > prop_threshold &  abs(FC_df[[FC_x]]) > FC_threshold , ]
    tmp_df = tmp_df[with(tmp_df, order(abs(tmp_df[[FC_x]]) , decreasing = TRUE)),]
    if ( length(row.names(tmp_df)) > 20) { selected = row.names(tmp_df)[1:20] }
    else{  selected = row.names(tmp_df) }

    FC_df$selection = ifelse( row.names(FC_df) %in% selected,
                              yes = "20 Highest FC expressed in most cells",no = FC_df$selection)
    FC_df$label = ifelse(FC_df$selection == "20 Highest FC expressed in most cells",
                         yes=row.names(FC_df), no="") }

  if(highlight[1] == "selection"){
    FC_df$label = ifelse(FC_df$selection == "Selected",
                         yes=row.names(FC_df), no="") }
  else{
    FC_df$selection = ifelse(row.names(FC_df) %in% highlight ,
                             yes = annotation, no = FC_df$selection)
    FC_df$label = ifelse(FC_df$selection == annotation,
                         yes=row.names(FC_df), no="") }


  maximum_x = max(abs(FC_df[[FC_x]])) + x_scale
  title =paste( c(title, "\n Gene selected :",selected_number),collapse = " " )

  plot = ggplot(FC_df, aes(x=FC_df[[FC_x]], y=FC_df[[y]]))+
    geom_point(aes(color=selection, alpha=selection, size = selection))+

    # Annotation of first filter
    annotate("text", y=-0.02, x=-FC_threshold-0.75,
             label=paste0("log2 FC = -",FC_threshold),
             colour = "darkblue") +
    geom_vline(xintercept = -FC_threshold, color='darkblue',linetype='dashed') +

    annotate("text", y=-0.02, x= FC_threshold+0.75,
             label=paste0("log2 FC = ",FC_threshold),
             colour = "darkblue") +
    geom_vline(xintercept = FC_threshold, color='darkblue',linetype='dashed') +
    # Proportion line
    geom_hline(yintercept = prop_threshold, color='darkblue',linetype='dashed') +


    coord_cartesian(xlim=c(-maximum_x,maximum_x), ylim=c(-0.025,1)) +

    scale_color_manual(values = c("orangered","#777777","#00539CFF"))+
    scale_alpha_manual(values=c(1,0.25, 0.75), guide='none')+
    scale_size_manual(values=c(2,0.5,1), guide='none')+

    theme_linedraw()+
    theme(legend.position = c(0.15, 0.85) ,legend.direction = 'vertical') +
    labs(color="Features")+
    ylab("Proportion of cells that express a gene") +
    xlab("log ratio of expression") +
    ggtitle(title)

  if (add_label){
    plot = plot +
      geom_text_repel(data=FC_df, label = FC_df$label,
                      vjust = vjust, force=force, max.overlaps = 100) }
  # Annotation of 2nd filter
  if (Display_2nd_annotation){
    plot = plot +
      annotate("text", y=-0.04, x=-FC_thresh2-1,
               label=paste0("log2 FC = -",round(FC_thresh2, digits = 3)),
               colour = '#555555') +
      geom_vline(xintercept = -FC_thresh2, color='#555555',linetype='dashed') +

      annotate("text", y=-0.04, x= FC_thresh2+1,
               label=paste0("log2 FC = ",label=round(FC_thresh2, digits = 3)  ),
               colour = '#555555') +
      geom_vline(xintercept = FC_thresh2, color='#555555',linetype='dashed')  }

  if (prop_threshold < 0.1) {
    plot = plot + annotate("text", y=0.05, x= maximum_x*0.75,
                           label=paste0("Proportion of \n cells expressing = ", prop_threshold_to_show),
                           colour = "darkblue") }
  else {
    plot = plot + annotate("text", y=prop_threshold*1.15, x= -maximum_x*0.75,
                           label=paste0("Proportion of cells expressing = ", round(prop_threshold, 3)),
                           colour = "darkblue") }

  return(list("plot"=plot, "df"=FC_df)) }


#' Imports csv
#'
#' @param directory
#' @param pattern2
#' @param pattern1
#'
#' @return
#' @export
#' @importFrom dplyr mutate_all
#' @examples
get_permutation_list = function(directory,pattern2,pattern1="Permutation_result_"){
  # Import files
  tmp = list.files(directory, full.names = TRUE,
                   recursive = TRUE, pattern=pattern1)

  if (pattern1 == "Permutation_result_") {
    Permutation_list = lapply(tmp,
                              function(x) x = read.csv2(x, header = TRUE,
                                                        sep = ",", row.names = 1))}
  else {
    Permutation_list = lapply(tmp, function(x) {
      x = read.table(x, header = TRUE , sep=",", row.names=2) } )}

  names(Permutation_list) = tmp
  # Rename each dataframe
  names(Permutation_list) = str_remove_all(
    string = names(Permutation_list) ,
    pattern = paste0(directory , pattern2))
  names(Permutation_list) = str_remove_all(string = names(Permutation_list) ,
                                           pattern =".csv")
  # Change data to numeric
  Permutation_list = lapply(Permutation_list, function(df) {
    df = dplyr::mutate_all(df, function(x) as.numeric(as.character(x) )) } )

  # return(list('l'=0,
  #             "dir"=paste0(directory , pattern2),
  #             "names"=names(Permutation_list) ) ) }
  return(Permutation_list)  }


#' extract genes from binary dataframe. Does the inverse of geneset_to_binary_df
#'
#' @param binary_df dataframe with 0 and 1
#' @param expressed_genes vector set of genes to keep
#' @param filter_expressed FALSE
#'
#' @return
#' @export
#'
#' @examples
get_genes_from_binary=function(binary_df, expressed_genes=NULL, filter_expressed = FALSE ){
  cell_types = colnames(binary_df)
  cell_geneslist = lapply(cell_types, function(cell){
    #gene_list = list()
    gene_list = row.names(binary_df[ binary_df[[cell]] != 0 , ])
    gene_list = gene_list[gene_list %in% expressed_genes]
    return(gene_list) })

  names(cell_geneslist) = cell_types
  return(cell_geneslist) }


#' computes median returns a named vector
#'
#' @param df dataframe
#' @param col_to_keep str
#'
#' @return
#' @export
#' @importFrom reshape2 melt
#' @examples
compute_median_expr=function(df,col_to_keep){
  df = df[,col_to_keep]
  df$genes = row.names(df)
  df_melt = melt(df)
  return (median(df_melt$value)) }

#' average value log2
#'
#' @param expr_A vector
#' @param expr_B vector
#'
#' @return
#' @export
#'
#' @examples
compute_Avalue=function(expr_A, expr_B){
  return(0.5* ( log2(expr_A+1) + log2(expr_B+1) ) ) }
#return(0.5* ( expr_A + expr_B ) ) }

#' Fold change computation
#'
#' @param expr_A
#' @param expr_B
#' @param median_expr
#'
#' @return
#' @export
#'
#' @examples
compute_FC=function(expr_A, expr_B, median_expr){
  return(log2( (expr_A+median_expr ) / (expr_B+median_expr) )) }
#return( (expr_A+median_expr ) / (expr_B+median_expr) ) }

#' RA value
#'
#' @param df
#' @param median_expr
#'
#' @return
#' @export
#' @importFrom stringr str_detect
#'
#' @examples
Get_value_RA = function(df, median_expr){
  A = colnames(df)[!str_detect(colnames(df), "vs|prop_expr")]
  B = colnames(df)[ str_detect(colnames(df), paste0("other_vs_",A)) ]
  B = B[! str_detect( B, "prop_expr")  ]
  df[[paste0("FC_",A)]] = compute_FC( df[[A]] , df[[B]] ,median_expr)
  df[[paste0("Avalue_",A)]] = compute_Avalue( df[[A]] , df[[B]] )
  return(df)
}



#' Does what it says
#'
#' @param conf_mat
#' @param cell_order
#' @param filter
#' @param column_filter
#' @param value_filter
#' @param direction_color_palette
#'
#' @return
#' @export
#' @import ggplot2
#' @examples
build_confusion_heatmap = function(conf_mat,cell_order,
                                   filter = FALSE,
                                   column_filter="signature_matrix",
                                   value_filter = "LM22",
                                   direction_color_palette = -1){
  cells_order = as.factor(cell_order)
  cells_order_Y = as.factor(rev(cell_order))

  if (direction_color_palette > 0){
    color1 = "white"
    color2 = "black"
  } else {
    color1 = "black"
    color2 = "white"
  }

  conf_mat$Percentage = round(conf_mat$Percentage*100,2)
  conf_mat$Percentage_show = paste0(as.character(conf_mat$Percentage),"%")

  if (filter){ conf_mat = conf_mat[conf_mat[[column_filter]] == value_filter , ] }

  plot = ggplot(data = conf_mat,
                aes(x=factor(Predicted_label, levels = cells_order),
                    y=factor(True_label, levels = cells_order_Y),
                    fill=Percentage)) +
    geom_tile(color="white")+
    # % cells predicted
    geom_text(data = conf_mat[conf_mat$Percentage > 30,],
              aes(label = Percentage_show), color = color2, size = 3, vjust=-1) +
    geom_text(data = conf_mat[conf_mat$Percentage <= 30,],
              aes(label = Percentage_show), color = color1, size = 3, vjust=-1) +

    # Number of cells predicted
    geom_text(data = conf_mat[conf_mat$Percentage > 30,],
              aes(label = value), color = color2, size = 3, vjust=1) +
    geom_text(data = conf_mat[conf_mat$Percentage <= 30,],
              aes(label = value), color = color1, size = 3, vjust=1) +

    xlab("Predicted labels") + ylab("True labels")+
    theme_minimal()+
    theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust=1))+
    scale_fill_viridis(option = "rocket", direction = direction_color_palette)

  return(list("plot"=plot, "conf_mat"=conf_mat)) }

#' import files
#'
#' @param directory
#' @param pattern2
#' @param pattern1
#' @param cells
#'
#' @return
#' @export
#' @importFrom reshape2 melt
#'
#' @examples
get_confusion = function(directory,pattern2,pattern1="confusion_heatmap_",
                         cells ){
  # Import files
  tmp = list.files(directory, full.names = TRUE,
                   recursive = TRUE, pattern=pattern1)

  conf_heamtap = read.csv2(tmp, header = FALSE, sep = " ", row.names = NULL)
  colnames(conf_heamtap) = cells
  row.names(conf_heamtap) = cells
  conf_mat_percent = conf_heamtap

  for (i in seq(1,nrow(conf_heamtap) )) {
    ncell = sum(conf_heamtap[i,])
    conf_mat_percent[i,] = conf_heamtap[i,] / ncell }

  colnames(conf_mat_percent) = cells
  row.names(conf_mat_percent) = cells
  conf_mat_percent$True_label = cells
  conf_mat_percent = melt(conf_mat_percent)

  colnames(conf_heamtap) = cells
  row.names(conf_heamtap) = cells
  conf_heamtap$True_label = cells
  conf_heamtap = melt(conf_heamtap)

  colnames(conf_mat_percent) = c("True_label","Predicted_label","Percentage")
  colnames(conf_heamtap) = c("True_label","Predicted_label","value")
  conf_mat = merge(conf_mat_percent,conf_heamtap)

  return(conf_mat)  }


#'  import files
#'
#' @param directory
#' @param pattern2
#' @param cells
#' @param signature_matrix
#' @param pattern1
#'
#' @return
#' @export
#'
#' @examples
confusion_matrix_setup = function(directory,pattern2,
                                  cells, signature_matrix,
                                  pattern1="confusion_heatmap_"){
  cf = get_confusion(
    directory = directory ,
    pattern2= "/confusion_heatmap_",
    cells = cells)

  balanced_acc = round(mean(cf[cf$True_label == cf$Predicted_label,]$Percentage)*100,2)
  cf$subtitle=paste0(signature_matrix, "\n Balanced accuracy = ",balanced_acc,"%")
  cf$signature_matrix = signature_matrix
  return(cf) }

#' Does what it says
#'
#' @param pattern2
#' @param tbs_path
#' @param lm22_path
#' @param til10_path
#' @param cells
#'
#' @return
#' @export
#'
#' @examples
merge_confusion_matrix = function(pattern2, tbs_path,lm22_path,til10_path,cells){
  cf1 = confusion_matrix_setup(
    directory = tbs_path,
    pattern2= "/confusion_heatmap_",
    cells = cells,
    signature_matrix = "Tabula Sapiens")
  cf2 = confusion_matrix_setup(
    directory = lm22_path,
    pattern2= "/confusion_heatmap_",
    cells = cells,
    signature_matrix = "LM22")

  cf3 = confusion_matrix_setup(
    directory = til10_path,
    pattern2= "/confusion_heatmap_",
    cells = cells,
    signature_matrix = "TIL10")
  return(rbind(cf1,cf2,cf3)) }

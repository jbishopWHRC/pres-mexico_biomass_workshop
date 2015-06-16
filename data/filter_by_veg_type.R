# Develop models for filtering outliers
# A function that makes it easy for us to plot the data and model fit
model_plot <- function(ds, veg_code, model_order, x_name, y_name){
  s <- subset(ds, type_code == veg_code)
  attach(s)
  x <- get(x_name)
  y <- get(y_name)
  detach()
  o <- order(x)
  mdf <- data.frame(x[o],y[o])
  m <- lm(mdf$y.o ~ poly(mdf$x.o, model_order))
  #mdf$pred <- predict(m, poly(mdf$x.o, model_order))
  mdf$residuals <- resid(m)
  std_dev <- sd(mdf$residuals)
  plot(mdf$x.o, mdf$y.o, main=paste(veg_code, model_order, y_name, std_dev, sep=" - "), pch=19, col='grey', xlab=x_name, ylab=y_name)
  lines(mdf$x.o, fitted(m), col='red', lwd=4)
  mdf$remove <- ifelse(mdf$residuals > 2 * std_dev, TRUE, FALSE)
  points(mdf$x.o[mdf$remove == FALSE], mdf$y.o[mdf$remove == FALSE], pch=21)
}

# Test some models
model_plot(sub, "TDF", 2, 'carbono_arboles_tpha', 'vcf_mean')
model_plot(sub, "TDF", 3, 'carbono_arboles_tpha', 'vcf_mean')
model_plot(sub, "TDF", 4, 'carbono_arboles_tpha', 'vcf_mean')

veg_codes <- c("TDF","THF","MG","CBF","BF","CF")
model_orders <- c(2,3,4)
y_names <- c('hv_mean', 'vcf_mean')

for (veg_code in veg_codes){
  for (y_name in y_names){
    for (model_order in model_orders){
      model_plot(sub, veg_code, model_order, 'carbono_arboles_tpha', y_name)
    }
  }
}
veg_codes <- c("TDF","THF","MG","CBF","BF","CF")
hv_model_orders <- c(4, 3, 2, 3, 3, 2)
vcf_model_orders <- c(4, 3, 2, 3, 3, 4)
veg_mods <- data.frame(veg_codes, hv_model_orders, vcf_model_orders)
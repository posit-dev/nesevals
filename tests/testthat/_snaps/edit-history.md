# format_edit_history_diffs snapshot with real sample

    Code
      cat(format_edit_history_diffs(input$edit_history))
    Output
      ## Edit History
      
      The following are the latest edits made by the user, from earlier to later.
      
      ```P1.py
      @@ -85,8 +85,9 @@
               ridge.fit(X_scaled, y)
               coef_ridge.append(ridge.coef_)
               
               # Lasso
               lasso = Lasso(alpha=alpha, max_iter=2000)
               lasso.fit(X_scaled, y)
      +        c
           
           # OLS (sin regularización)
      ```
      
      ```P1.py
      @@ -85,8 +85,9 @@
               ridge.fit(X_scaled, y)
               coef_ridge.append(ridge.coef_)
               
               # Lasso
               lasso = Lasso(alpha=alpha, max_iter=2000)
               lasso.fit(X_scaled, y)
      +        coef_l
           
           # OLS (sin regularización)
      ```
      
      ```P1.py
      @@ -85,8 +85,9 @@
               ridge.fit(X_scaled, y)
               coef_ridge.append(ridge.coef_)
               
               # Lasso
               lasso = Lasso(alpha=alpha, max_iter=2000)
               lasso.fit(X_scaled, y)
      +        coef_lasso.
           
           # OLS (sin regularización)
      ```
      
      ```P1.py
      @@ -85,8 +85,9 @@
               ridge.fit(X_scaled, y)
               coef_ridge.append(ridge.coef_)
               
               # Lasso
               lasso = Lasso(alpha=alpha, max_iter=2000)
               lasso.fit(X_scaled, y)
      +        coef_lasso.app
           
           # OLS (sin regularización)
      ```
      
      ```P1.py
      @@ -85,8 +85,9 @@
               ridge.fit(X_scaled, y)
               coef_ridge.append(ridge.coef_)
               
               # Lasso
               lasso = Lasso(alpha=alpha, max_iter=2000)
               lasso.fit(X_scaled, y)
      +        coef_lasso.append(lasso.
           
           # OLS (sin regularización)
      ```

# format_edit_history_before_after snapshot with real sample

    Code
      cat(format_edit_history_before_after(input$edit_history))
    Output
      ## Edit History
      
      Edits are in least-to-most recent order.
      
      ### Edit 1:
      
      Before:
      
      ```
              lasso.fit(X_scaled, y)
          
      ```
      
      After:
      
      ```
              lasso.fit(X_scaled, y)
              c
          
      ```
      
      ### Edit 2:
      
      After:
      
      ```
              lasso.fit(X_scaled, y)
              coef_l
          
      ```
      
      ### Edit 3:
      
      After:
      
      ```
              lasso.fit(X_scaled, y)
              coef_lasso.
          
      ```
      
      ### Edit 4:
      
      After:
      
      ```
              lasso.fit(X_scaled, y)
              coef_lasso.app
          
      ```
      
      ### Edit 5:
      
      After:
      
      ```
              lasso.fit(X_scaled, y)
              coef_lasso.append(lasso.
          
      ```

# format_edit_history_narrative snapshot with real sample

    Code
      cat(format_edit_history_narrative(input$edit_history))
    Output
      ## Edit History
      
      The user's code started like this:
      
      ```
              lasso.fit(X_scaled, y)
          
      ```
      
      Then, the user added `c`:
      
      ```
              lasso.fit(X_scaled, y)
              c
          
      ```
      
      Then, the user typed `oef_l`:
      
      ```
              lasso.fit(X_scaled, y)
              coef_l
          
      ```
      
      Then, the user typed `asso.`:
      
      ```
              lasso.fit(X_scaled, y)
              coef_lasso.
          
      ```
      
      Then, the user typed `app`:
      
      ```
              lasso.fit(X_scaled, y)
              coef_lasso.app
          
      ```
      
      Most recently, the user typed `end(lasso.`:
      
      ```
              lasso.fit(X_scaled, y)
              coef_lasso.append(lasso.
          
      ```

# format_edit_history_diffs snapshot with real sample 2

    Code
      cat(format_edit_history_diffs(input$edit_history))
    Output
      ## Edit History
      
      The following are the latest edits made by the user, from earlier to later.
      
      ```pvalues.py
      @@ -60,6 +60,8 @@ def get_pvalues(key, p0s, maxit, test_statistic,
       	pvalue = get_pvalue(test_statistic_value=value,
       						threshold=quantiles,
       						tol=tol,
       						maxit=maxit,
       						upper_alpha=upper_alpha)
      +
      +	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
       
       	return pvalue
      ```
      
      ```pvalues.py
      @@ -62,6 +62,9 @@ def get_pvalues(key, p0s, maxit, test_statistic,
       						maxit=maxit,
       						upper_alpha=upper_alpha)
       
       	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      +	p = ggplot(Ts_df, aes(x="T")) + geom_histogram(bins=30) + theme_minimal()
       
       	return pvalue
      ```
      
      ```pvalues.py
      @@ -63,6 +63,6 @@ def get_pvalues(key, p0s, maxit, test_statistic,
       
       	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      -	p = ggplot(Ts_df, aes(x="T")) + geom_histogram(bins=30) + theme_minimal()
      +	p = ggplot(Ts_df, aes(x="T", fill="")) + geom_histogram(bins=30) + theme_minimal()
       
       	return pvalue
      ```
      
      ```pvalues.py
      @@ -63,6 +63,6 @@ def get_pvalues(key, p0s, maxit, test_statistic,
       
       	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      -	p = ggplot(Ts_df, aes(x="T", fill="")) + geom_histogram(bins=30) + theme_minimal()
      +	p = ggplot(Ts_df, aes(x="T", fill="p")) + geom_histogram(bins=30) + theme_minimal()
       
       	return pvalue
      ```

# format_edit_history_before_after snapshot with real sample 2

    Code
      cat(format_edit_history_before_after(input$edit_history))
    Output
      ## Edit History
      
      Edits are in least-to-most recent order.
      
      ### Edit 1:
      
      Before:
      
      ```
      						upper_alpha=upper_alpha)
      
      ```
      
      After:
      
      ```
      						upper_alpha=upper_alpha)
      
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      
      ```
      
      ### Edit 2:
      
      Before:
      
      ```
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      
      ```
      
      After:
      
      ```
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      	p = ggplot(Ts_df, aes(x="T")) + geom_histogram(bins=30) + theme_minimal()
      
      ```
      
      ### Edit 3:
      
      After:
      
      ```
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      	p = ggplot(Ts_df, aes(x="T", fill="")) + geom_histogram(bins=30) + theme_minimal()
      
      ```
      
      ### Edit 4:
      
      After:
      
      ```
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      	p = ggplot(Ts_df, aes(x="T", fill="p")) + geom_histogram(bins=30) + theme_minimal()
      
      ```

# format_edit_history_narrative snapshot with real sample 2

    Code
      cat(format_edit_history_narrative(input$edit_history))
    Output
      ## Edit History
      
      The user's code started like this:
      
      ```
      						upper_alpha=upper_alpha)
      
      ```
      
      Then, the user added 2 lines:
      
      ```
      						upper_alpha=upper_alpha)
      
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      
      ```
      
      Then, the user added `p = ggplot(Ts_df, aes(x="T")) + geom_histogram(bins=30) + theme_minimal()`:
      
      ```
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      	p = ggplot(Ts_df, aes(x="T")) + geom_histogram(bins=30) + theme_minimal()
      
      ```
      
      Then, the user changed `p = ggplot(Ts_df, aes(x="T")) + geom_histogram(bins=30) + theme_minimal()` to `p = ggplot(Ts_df, aes(x="T", fill="")) + geom_histogram(bins=30) + theme_minimal()`:
      
      ```
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      	p = ggplot(Ts_df, aes(x="T", fill="")) + geom_histogram(bins=30) + theme_minimal()
      
      ```
      
      Most recently, the user changed `p = ggplot(Ts_df, aes(x="T", fill="")) + geom_histogram(bins=30) + theme_minimal()` to `p = ggplot(Ts_df, aes(x="T", fill="p")) + geom_histogram(bins=30) + theme_minimal()`:
      
      ```
      	Ts_df = pd.DataFrame({"p0": onp.repeat(p0s, B), "T": Ts.reshape(-1)})
      	p = ggplot(Ts_df, aes(x="T", fill="p")) + geom_histogram(bins=30) + theme_minimal()
      
      ```


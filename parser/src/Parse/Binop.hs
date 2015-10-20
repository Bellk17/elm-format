module Parse.Binop (binops) where

import qualified Data.List as List
import Text.Parsec ((<|>), choice, try)

import AST.V0_15
import qualified AST.Expression as E
import qualified AST.Variable as Var
import Parse.Helpers (IParser, commitIf, whitespace, popNewlineContext, pushNewlineContext)
import qualified Reporting.Annotation as A


binops
    :: IParser E.Expr
    -> IParser E.Expr
    -> IParser (Commented Var.Ref)
    -> IParser E.Expr
binops term last anyOp =
  do  pushNewlineContext
      e <- term
      ops <- nextOps
      sawNewline <- popNewlineContext
      return $ split e ops sawNewline
  where
    nextOps =
      choice
        [ commitIf (whitespace >> anyOp) $
            do  whitespace
                op <- anyOp
                whitespace
                expr <- Left <$> try term <|> Right <$> last
                case expr of
                  Left t -> (:) (op,t) <$> nextOps
                  Right e -> return [(op,e)]
        , return []
        ]


split
    :: E.Expr
    -> [(Commented Var.Ref, E.Expr)]
    -> Bool
    -> E.Expr
split e0 [] _ = e0
split e0 ops multiline =
    let
        init :: A.Located (E.Expr,[(Commented Var.Ref,E.Expr)])
        init = A.sameAs e0 (e0,[])

        merge'
          :: (Commented Var.Ref, E.Expr)
          -> A.Located x
          -> (E.Expr,[(Commented Var.Ref,E.Expr)])
          -> A.Located (E.Expr,[(Commented Var.Ref,E.Expr)])
        merge' (o,e) loc (e0,ops) =
          A.merge e loc (e0,(o,e):ops)

        merge
          :: (Commented Var.Ref, E.Expr)
          -> A.Located (E.Expr,[(Commented Var.Ref,E.Expr)])
          -> A.Located (E.Expr,[(Commented Var.Ref,E.Expr)])
        merge (o,e) loc =
          merge' (o,e) loc (A.drop loc)

        wrap :: (E.Expr,[(Commented Var.Ref,E.Expr)]) -> E.Expr'
        wrap (e',ops) = E.Binops e' ops multiline
    in
      A.map wrap $ List.foldr merge init ops

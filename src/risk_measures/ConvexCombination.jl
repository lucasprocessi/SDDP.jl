#  Copyright 2018, Oscar Dowson
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################

import Base: +, *

export EAVaR

"""
    ConvexCombination( (weight::Float64, measure::AbstractRiskMeasure) ... )

Create a weighted combination of risk measures.

### Examples

    ConvexCombination(
        (0.5, Expectation()),
        (0.5, AVaR(0.25))
    )

Convex combinations can also be constructed by adding weighted risk measures
together as follows:

    0.5 * Expectation() + 0.5 * AVaR(0.5)

"""
struct ConvexCombination{T<:Tuple} <: AbstractRiskMeasure
    measures::T
end
ConvexCombination(args::Tuple...) = ConvexCombination(args)

function (+)(a::ConvexCombination, b::ConvexCombination)
    return ConvexCombination(a.measures..., b.measures...)
end

function (*)(lhs::Float64, rhs::AbstractRiskMeasure)
    return ConvexCombination( ( (lhs, rhs), ) )
end

function modify_probability(riskmeasure::ConvexCombination,
                            riskadjusted_distribution,
                            original_distribution::Vector{Float64},
                            observations::Vector{Float64},
                            model::SDDPModel,
                            subproblem::JuMP.Model)
    riskadjusted_distribution .= 0.0
    partial_distribution = similar(original_distribution)
    for (weight, measure) in riskmeasure.measures
        partial_distribution .= 0.0
        modify_probability(measure, partial_distribution, original_distribution,
                           observations, model, subproblem)
        riskadjusted_distribution .+= weight * partial_distribution
    end
end

"""
    EAVaR(;lambda=1.0, beta=1.0)

# Description

A risk measure that is a convex combination of Expectation and Average Value @
Risk (also called Conditional Value @ Risk).

    λ * E[x] + (1 - λ) * AV@R(1-β)[x]

# Keyword Arguments

 * `lambda`
 Convex weight on the expectation (`(1-lambda)` weight is put on the AV@R
 component. Inreasing values of `lambda` are less risk averse (more weight on
 expecattion)

 * `beta`
 The quantile at which to calculate the Average Value @ Risk. Increasing values
 of `beta` are less risk averse. If `beta=0`, then the AV@R component is the
 worst case risk measure.
"""
function EAVaR(;lambda::Float64=1.0, beta::Float64=1.0)
    if !(0.0 <= lambda <= 1.0)
        error("Lambda must be in the range [0, 1]. Increasing values of " *
              "lambda are less risk averse. lambda=1 is identical to taking " *
              "the expectation.")
    end
    if !(0.0 <= beta <= 1.0)
        error("Beta must be in the range [0, 1]. Increasing values of beta " *
              "are less risk averse. lambda=1 is identical to taking the " *
              "expectation.")
    end
    return lambda * Expectation() + (1 - lambda) * AVaR(beta)
end

local util = {}

function util.in_box(vert, x1, x2, y1, y2)
	if x2 < x1 then
        x1, x2 = x2, x1
    end

    if y2 < y1 then
        y1, y2 = y2, y1
    end

    if vert[1] >= x1 and vert[2] >= y1 and vert[1] <= x2 and vert[2] <= y2 then
        return true
    end
end

function util.in_table(table, value)
	for i, test in pairs(table) do
		if test == value then
			return true
		end
	end

	return false
end

function util.in_array(array, value)
	for i, test in ipairs(array) do
		if test == value then
			return true
		end
	end

	return false
end

function util.find_nearby_vert(list, vert, dist)
	for i, test in pairs(list) do
		if test ~= vert and math.sqrt((vert[1]-test[1])^2 + (vert[2]-test[2])^2) <= dist then
			return test
		end
	end

	return nil
end

function util.line_on_circle(a, b, c, r)
    local d = {
        b[1] - a[1],
        b[2] - a[2]
    }

    local f = {
        a[1] - c[1],
        a[2] - c[2]
    }

    local a = (d[1]^2 + d[2]^2)
    local b = 2 * (f[1] * d[1] + f[2] * d[2])
    local c = (f[1]^2 + f[2]^2) - r^2

    local discriminant = b * b - 4 * a * c

    if discriminant < 0 then
        return false
    end

    discriminant = math.sqrt(discriminant)

    local t1 = (-b - discriminant) / (2 * a)
    local t2 = (-b + discriminant) / (2 * a)

    return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1)
end

function util.point_in_triangle(x, y, p0, p1, p2)
    local A = 1/2 * (-p1[2] * p2[1] + p0[2] * (-p1[1] + p2[1]) + p0[1] * (p1[2] - p2[2]) + p1[1] * p2[2])
    local sign

    if A < 0 then
        sign = -1
    else
        sign = 1
    end

    local s = (p0[2] * p2[1] - p0[1] * p2[2] + (p2[2] - p0[2]) * x + (p0[1] - p2[1]) * y) * sign
    local t = (p0[1] * p1[2] - p0[2] * p1[1] + (p0[2] - p1[2]) * x + (p1[1] - p0[1]) * y) * sign

    return s > 0 and t > 0 and (s + t) < 2 * A * sign
end

return util
